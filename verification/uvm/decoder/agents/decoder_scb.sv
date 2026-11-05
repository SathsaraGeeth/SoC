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

class decoder_scb extends uvm_scoreboard;
    `uvm_component_utils(decoder_scb)

    uvm_analysis_export #(decoder_txn) after_export;
    uvm_tlm_analysis_fifo #(decoder_txn) after_fifo;

    function new(string name = "decoder_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
        after_fifo   = new("after_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        after_export.connect(after_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        decoder_txn txn;

        forever begin
            after_fifo.get(txn);
            if (txn.decoded.raw !== txn.instr)
                `uvm_error("DECODER_SCB", "Raw instruction was not preserved")
            if (txn.decoded.rd !== txn.instr[11:7] ||
                (txn.case_id != 10 && txn.decoded.rs1 !== txn.instr[19:15]) ||
                txn.decoded.rs2 !== txn.instr[24:20])
                `uvm_error("DECODER_SCB", "Register fields were decoded incorrectly")

            unique case (txn.case_id)
                0: check_alu(txn, isa_pkg::ALU_ADD, 1'b0);
                1: check_alu(txn, isa_pkg::ALU_SUB, 1'b0);
                2: check_alu(txn, isa_pkg::ALU_AND, 1'b0);
                3: begin
                    check_alu(txn, isa_pkg::ALU_ADD, 1'b1);
                    check_imm(txn, {{52{txn.instr[31]}}, txn.instr[31:20]});
                    if (txn.decoded.rawhz_t != RAWHZ_RS1)
                        `uvm_error("DECODER_SCB", "ADDI hazard class mismatch")
                end
                4, 5: begin
                    if (txn.decoded.fu != FU_LSU || !txn.decoded.use_imm ||
                        txn.decoded.rawhz_t != RAWHZ_RS1 || txn.decoded.ls_wen)
                        `uvm_error("DECODER_SCB", "Load control mismatch")
                    check_imm(txn, {{52{txn.instr[31]}}, txn.instr[31:20]});
                end
                6: begin
                    if (txn.decoded.fu != FU_LSU || !txn.decoded.use_imm ||
                        txn.decoded.rawhz_t != RAWHZ_RS1_RS2 || !txn.decoded.ls_wen)
                        `uvm_error("DECODER_SCB", "Store control mismatch")
                    check_imm(txn, {{52{txn.instr[31]}}, txn.instr[31:25],
                                    txn.instr[11:7]});
                end
                7: begin
                    if (txn.decoded.fu != FU_ALU || !txn.decoded.is_branch ||
                        !txn.decoded.use_imm || txn.decoded.rawhz_t != RAWHZ_RS1_RS2)
                        `uvm_error("DECODER_SCB", "Branch control mismatch")
                    check_imm(txn, {{51{txn.instr[31]}}, txn.instr[31],
                                    txn.instr[7], txn.instr[30:25],
                                    txn.instr[11:8], 1'b0});
                end
                8: begin
                    if (txn.decoded.fu != FU_ALU || !txn.decoded.is_jump ||
                        txn.decoded.is_jalr || !txn.decoded.use_imm)
                        `uvm_error("DECODER_SCB", "JAL control mismatch")
                end
                9: begin
                    if (txn.decoded.fu != FU_ALU || !txn.decoded.is_jump ||
                        !txn.decoded.is_jalr || txn.decoded.rawhz_t != RAWHZ_RS1)
                        `uvm_error("DECODER_SCB", "JALR control mismatch")
                    check_imm(txn, {{52{txn.instr[31]}}, txn.instr[31:20]});
                end
                10: begin
                    if (txn.decoded.fu != FU_ALU || !txn.decoded.use_imm ||
                        txn.decoded.use_pc || txn.decoded.rs1 != '0)
                        `uvm_error("DECODER_SCB", "LUI control mismatch")
                    check_imm(txn, {{32{txn.instr[31]}}, txn.instr[31:12], 12'b0});
                end
                11: begin
                    if (txn.decoded.fu != FU_ALU || !txn.decoded.use_imm ||
                        !txn.decoded.use_pc)
                        `uvm_error("DECODER_SCB", "AUIPC control mismatch")
                    check_imm(txn, {{32{txn.instr[31]}}, txn.instr[31:12], 12'b0});
                end
                12: begin
                    if (txn.decoded.fu != FU_CSR || !txn.decoded.csr_wen ||
                        txn.decoded.rawhz_t != RAWHZ_RS1)
                        `uvm_error("DECODER_SCB", "CSR control mismatch")
                end
                default: begin
                    if (txn.decoded.fu != FU_ALU || txn.decoded.rf_wen ||
                        txn.decoded.csr_wen || txn.decoded.ls_wen)
                        `uvm_error("DECODER_SCB", "Illegal/default decode mismatch")
                end
            endcase
        end
    endtask: run_phase

    function void check_alu(decoder_txn txn, isa_pkg::alu_op_e op, bit use_imm);
        if (txn.decoded.fu != FU_ALU || txn.decoded.alu_op != op ||
            txn.decoded.use_imm != use_imm)
            `uvm_error("DECODER_SCB", "Integer ALU decode mismatch")
        if (txn.decoded.rd != '0 && !txn.decoded.rf_wen)
            `uvm_error("DECODER_SCB", "Destination write enable missing")
    endfunction

    function void check_imm(decoder_txn txn, bit [core_pkg::XLEN-1:0] expected);
        if (txn.decoded.imm !== expected)
            `uvm_error("DECODER_SCB",
                $sformatf("Immediate mismatch expected=0x%016h actual=0x%016h",
                          expected, txn.decoded.imm))
    endfunction
endclass: decoder_scb
