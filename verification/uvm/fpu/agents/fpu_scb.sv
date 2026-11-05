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

class fpu_scb extends uvm_scoreboard;
    `uvm_component_utils(fpu_scb)

    uvm_analysis_export #(fpu_txn) before_export;
    uvm_tlm_analysis_fifo #(fpu_txn) before_fifo;
    uvm_analysis_export #(fpu_txn) after_export;
    uvm_tlm_analysis_fifo #(fpu_txn) after_fifo;
    fpu_txn expected[$];

    function new(string name = "fpu_scb", uvm_component parent = null);
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
        fpu_txn txn;

        forever begin
            before_fifo.get(txn);
            txn.result = predict(txn.op, txn.a, txn.b);
            expected.push_back(txn);
        end
    endtask: predict_requests

    task compare_results();
        fpu_txn actual;
        fpu_txn exp;

        forever begin
            after_fifo.get(actual);
            if (expected.size() == 0) begin
                `uvm_error("FPU_SCB", "Result observed without a request")
            end else begin
                exp = expected.pop_front();
                if (actual.result !== exp.result)
                    `uvm_error("FPU_SCB",
                        $sformatf("Result mismatch op=%0d expected=0x%016h actual=0x%016h",
                                  exp.op, exp.result, actual.result))
                if (actual.thrd_id !== exp.thrd_id)
                    `uvm_error("FPU_SCB", "Thread tag mismatch")
            end
        end
    endtask: compare_results

    function bit [XLEN-1:0] predict(
        isa_pkg::fpu_op_e op,
        bit [31:0] a,
        bit [31:0] b
    );
        unique case (op)
            isa_pkg::FPU_FSGNJ:   return {32'b0, b[31], a[30:0]};
            isa_pkg::FPU_FSGNJN:  return {32'b0, ~b[31], a[30:0]};
            isa_pkg::FPU_FSGNJX:  return {32'b0, a[31] ^ b[31], a[30:0]};
            isa_pkg::FPU_FCMP_EQ: return XLEN'(fp32_eq(a, b));
            isa_pkg::FPU_FCMP_LT: return XLEN'(fp32_lt(a, b));
            isa_pkg::FPU_FCMP_LE: return XLEN'(fp32_lt(a, b) || fp32_eq(a, b));
            isa_pkg::FPU_FMIN:
                return is_nan(a) ? {32'b0, b} :
                       is_nan(b) ? {32'b0, a} :
                       fp32_lt(b, a) ? {32'b0, b} : {32'b0, a};
            isa_pkg::FPU_FMAX:
                return is_nan(a) ? {32'b0, b} :
                       is_nan(b) ? {32'b0, a} :
                       fp32_lt(a, b) ? {32'b0, b} : {32'b0, a};
            isa_pkg::FPU_FCLASS: return XLEN'(fp32_class(a));
            default: return '0;
        endcase
    endfunction: predict

    function bit is_nan(bit [31:0] value);
        return value[30:23] == 8'hff && value[22:0] != '0;
    endfunction

    function bit fp32_eq(bit [31:0] a, bit [31:0] b);
        if (is_nan(a) || is_nan(b))
            return 1'b0;
        return (a[30:0] == '0 && b[30:0] == '0) || a == b;
    endfunction

    function bit fp32_lt(bit [31:0] a, bit [31:0] b);
        if (is_nan(a) || is_nan(b) || fp32_eq(a, b))
            return 1'b0;
        if (a[31] != b[31])
            return a[31];
        return a[31] ? a[30:0] > b[30:0] : a[30:0] < b[30:0];
    endfunction

    function bit [9:0] fp32_class(bit [31:0] value);
        bit [9:0] result;

        result = '0;
        if (value[30:23] == 8'hff && value[22:0] == '0)
            result[value[31] ? 0 : 7] = 1'b1;
        else if (value[30:23] == 8'hff)
            result[value[22] ? 9 : 8] = 1'b1;
        else if (value[30:23] == '0 && value[22:0] == '0)
            result[value[31] ? 3 : 4] = 1'b1;
        else if (value[30:23] == '0)
            result[value[31] ? 2 : 5] = 1'b1;
        else
            result[value[31] ? 1 : 6] = 1'b1;
        return result;
    endfunction
endclass: fpu_scb

