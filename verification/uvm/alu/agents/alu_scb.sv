/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import uvm_pkg::*;
import core_pkg::*;
`include "uvm_macros.svh"

class alu_scb extends uvm_scoreboard;
    `uvm_component_utils(alu_scb)

    uvm_analysis_export #(alu_txn) before_export;
    uvm_tlm_analysis_fifo #(alu_txn) before_fifo;
    uvm_analysis_export #(alu_txn) after_export;
    uvm_tlm_analysis_fifo #(alu_txn) after_fifo;
    alu_txn expected[2][$];

    function new(string name = "alu_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        before_export = new("before_export", this);
        before_fifo   = new("before_fifo", this);
        after_export  = new("after_export", this);
        after_fifo    = new("after_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        before_export.connect(before_fifo.analysis_export);
        after_export.connect(after_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            predict_requests();
            compare_results();
        join
    endtask: run_phase

    task predict_requests();
        alu_txn txn;

        forever begin
            before_fifo.get(txn);
            predict(txn);
            expected[txn.lane].push_back(txn);
        end
    endtask: predict_requests

    task compare_results();
        alu_txn actual;
        alu_txn exp;

        forever begin
            after_fifo.get(actual);
            if (expected[actual.lane].size() == 0) begin
                `uvm_error("ALU_SCB", "Result observed without a request")
            end else begin
                exp = expected[actual.lane].pop_front();
                if (actual.result !== exp.result)
                    `uvm_error("ALU_SCB",
                        $sformatf("Result mismatch op=%0d expected=0x%016h actual=0x%016h",
                                  exp.op, exp.result, actual.result))
                if (actual.br_target !== exp.br_target ||
                    actual.br_taken !== exp.br_taken)
                    `uvm_error("ALU_SCB", "Branch metadata mismatch")
                if (actual.thrd_id !== exp.thrd_id)
                    `uvm_error("ALU_SCB", "Thread tag mismatch")
            end
        end
    endtask: compare_results

    function void predict(alu_txn txn);
        bit [XLEN-1:0] op_a;
        bit [XLEN-1:0] op_b;
        bit signed [XLEN-1:0] signed_a;
        bit signed [XLEN-1:0] signed_b;
        bit signed [2*XLEN-1:0] signed_product;
        bit signed [2*XLEN:0] mixed_product;
        bit [2*XLEN-1:0] unsigned_product;

        op_a = txn.control_kind inside {2, 3} ? txn.pc :
               txn.use_pc ? txn.pc : txn.a;
        op_b = txn.use_imm ? txn.imm : txn.b;
        signed_a = op_a;
        signed_b = op_b;
        signed_product   = signed_a * signed_b;
        mixed_product    = $signed({op_a[XLEN-1], op_a}) *
                           $signed({1'b0, op_b});
        unsigned_product = op_a * op_b;

        unique case (txn.op)
            isa_pkg::ALU_ADD:    txn.result = op_a + op_b;
            isa_pkg::ALU_SUB:    txn.result = op_a - op_b;
            isa_pkg::ALU_SLL:    txn.result = op_a << op_b[$clog2(XLEN)-1:0];
            isa_pkg::ALU_SLT:    txn.result = XLEN'($signed(op_a) < $signed(op_b));
            isa_pkg::ALU_SLTU:   txn.result = XLEN'(op_a < op_b);
            isa_pkg::ALU_XOR:    txn.result = op_a ^ op_b;
            isa_pkg::ALU_SRL:    txn.result = op_a >> op_b[$clog2(XLEN)-1:0];
            isa_pkg::ALU_SRA:    txn.result = $signed(op_a) >>> op_b[$clog2(XLEN)-1:0];
            isa_pkg::ALU_OR:     txn.result = op_a | op_b;
            isa_pkg::ALU_AND:    txn.result = op_a & op_b;
            isa_pkg::ALU_MUL:    txn.result = unsigned_product[XLEN-1:0];
            isa_pkg::ALU_MULH:   txn.result = signed_product[2*XLEN-1:XLEN];
            isa_pkg::ALU_MULHSU: txn.result = mixed_product[2*XLEN-1:XLEN];
            isa_pkg::ALU_MULHU:  txn.result = unsigned_product[2*XLEN-1:XLEN];
        endcase

        txn.br_target = txn.control_kind == 0 ? '0 :
                        txn.control_kind == 3
                      ? ((txn.a + txn.imm) & ~XLEN'(1))
                      : txn.pc + txn.imm;
        txn.br_taken = txn.control_kind inside {2, 3};
        if (txn.control_kind == 1) begin
            txn.result = txn.a - txn.b;
            unique case (txn.funct3)
                3'b000: txn.br_taken = txn.a == txn.b;
                3'b001: txn.br_taken = txn.a != txn.b;
                3'b100: txn.br_taken = $signed(txn.a) < $signed(txn.b);
                3'b101: txn.br_taken = $signed(txn.a) >= $signed(txn.b);
                3'b110: txn.br_taken = txn.a < txn.b;
                3'b111: txn.br_taken = txn.a >= txn.b;
                default: txn.br_taken = 1'b0;
            endcase
        end
        if (txn.control_kind inside {2, 3})
            txn.result = txn.pc + XLEN'(isa_pkg::INST_W / 8);
        if (txn.word_op)
            txn.result = {{(XLEN-32){txn.result[31]}}, txn.result[31:0]};
    endfunction: predict
endclass: alu_scb
