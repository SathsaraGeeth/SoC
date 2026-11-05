/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
import fpu_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_scb extends uvm_scoreboard;
    `uvm_component_utils(fpu_datapath_scb)

    uvm_analysis_export #(fpu_datapath_txn) before_export;
    uvm_tlm_analysis_fifo #(fpu_datapath_txn) before_fifo;
    uvm_analysis_export #(fpu_datapath_txn) after_export;
    uvm_tlm_analysis_fifo #(fpu_datapath_txn) after_fifo;
    fpu_datapath_txn expected[2][$];

    function new(string name = "fpu_datapath_scb", uvm_component parent = null);
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
            forever begin
                fpu_datapath_txn txn;
                before_fifo.get(txn);
                unique case (txn.op)
                    ADD: txn.result = 64'h0000_0000_4070_0000;
                    SUB: txn.result = 64'h0000_0000_4020_0000;
                    MUL: txn.result = 64'h0000_0000_4040_0000;
                    FMA: txn.result = 64'h0000_0000_4080_0000;
                    default: txn.result = 'x;
                endcase
                expected[txn.lane].push_back(txn);
            end
            forever begin
                fpu_datapath_txn actual;
                fpu_datapath_txn exp;
                after_fifo.get(actual);
                if (expected[actual.lane].size() == 0) begin
                    `uvm_error("FPU_DP_SCB", "Result observed without a request")
                end else begin
                    exp = expected[actual.lane].pop_front();
                    if (actual.result !== exp.result)
                        `uvm_error("FPU_DP_SCB", $sformatf(
                            "Lane %0d result mismatch op=%0d expected=0x%016h actual=0x%016h",
                            actual.lane, exp.op, exp.result, actual.result))
                    if (actual.thrd !== exp.thrd)
                        `uvm_error("FPU_DP_SCB", "Thread tag mismatch")
                end
            end
        join
    endtask: run_phase
endclass: fpu_datapath_scb
