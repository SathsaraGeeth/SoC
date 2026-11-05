/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mac20i_v2_scb extends uvm_scoreboard;
    `uvm_component_utils(mac20i_v2_scb)
    uvm_analysis_export #(mac20i_v2_txn) before_export, after_export;
    uvm_tlm_analysis_fifo #(mac20i_v2_txn) before_fifo, after_fifo;
    mac20i_v2_txn expected[$];
    function new(string name = "mac20i_v2_scb", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); before_export = new("before_export", this); before_fifo = new("before_fifo", this); after_export = new("after_export", this); after_fifo = new("after_fifo", this); endfunction
    function void connect_phase(uvm_phase phase); before_export.connect(before_fifo.analysis_export); after_export.connect(after_fifo.analysis_export); endfunction
    task run_phase(uvm_phase phase);
        fork
            forever begin mac20i_v2_txn txn; int signed sum; before_fifo.get(txn); sum = 0; for (int i = 0; i < txn.terms; i++) sum += $signed(txn.a[i]) * $signed(txn.b[i]); txn.result = sum[7:0]; expected.push_back(txn); end
            forever begin mac20i_v2_txn actual, exp; after_fifo.get(actual); if (expected.size() == 0) `uvm_error("MAC20I_SCB", "Result without request") else begin exp = expected.pop_front(); if (actual.result !== exp.result) `uvm_error("MAC20I_SCB", $sformatf("Expected 0x%02h actual 0x%02h", exp.result, actual.result)) end end
        join
    endtask
endclass: mac20i_v2_scb
