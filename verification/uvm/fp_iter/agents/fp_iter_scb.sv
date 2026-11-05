/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_scb extends uvm_scoreboard;
    `uvm_component_utils(fp_iter_scb)

    uvm_analysis_export #(fp_iter_txn) before_export;
    uvm_tlm_analysis_fifo #(fp_iter_txn) before_fifo;
    uvm_analysis_export #(fp_iter_txn) after_export;
    uvm_tlm_analysis_fifo #(fp_iter_txn) after_fifo;
    fp_iter_txn expected[2][$];

    function new(string name = "fp_iter_scb", uvm_component parent = null);
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
                fp_iter_txn txn;
                before_fifo.get(txn);
                unique case (txn.kind)
                    0, 1: txn.result = txn.bypass_result;
                    2: txn.result = 64'h0000_0000_7f80_0000;
                    default: txn.result = 64'h0000_0000_7fc0_0000;
                endcase
                expected[txn.kind == 0 ? 0 : 1].push_back(txn);
            end
            forever begin
                fp_iter_txn actual;
                fp_iter_txn exp;
                int lane;
                after_fifo.get(actual);
                lane = actual.kind[0];
                if (expected[lane].size() == 0) begin
                    `uvm_error("FP_ITER_SCB", "Result observed without a request")
                end else begin
                    exp = expected[lane].pop_front();
                    if (actual.result !== exp.result)
                        `uvm_error("FP_ITER_SCB", $sformatf(
                            "Result mismatch kind=%0d expected=0x%016h actual=0x%016h",
                            exp.kind, exp.result, actual.result))
                    if (actual.thrd !== exp.thrd)
                        `uvm_error("FP_ITER_SCB", "Thread tag mismatch")
                end
            end
        join
    endtask
endclass: fp_iter_scb
