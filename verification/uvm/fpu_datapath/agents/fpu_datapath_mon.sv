/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_mon extends uvm_monitor;
    `uvm_component_utils(fpu_datapath_mon)

    virtual fpu_datapath_if vif;
    uvm_analysis_port #(fpu_datapath_txn) before_ap;
    uvm_analysis_port #(fpu_datapath_txn) after_ap;

    function new(string name = "fpu_datapath_mon", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap  = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_datapath_if)::get(this, "", "vif", vif))
            `uvm_fatal("FPU_DP_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fpu_datapath_txn txn;

        forever begin
            @(posedge vif.clk);
            for (int lane = 0; lane < 2; lane++) begin
                if (vif.rst_n && vif.in_valid[lane] && vif.in_ready[lane]) begin
                    txn = fpu_datapath_txn::type_id::create("request_txn");
                    txn.lane = lane[0];
                    txn.op   = vif.op[lane];
                    txn.thrd = vif.in_thrd[lane];
                    txn.a    = vif.a[lane];
                    txn.b    = vif.b[lane];
                    txn.c    = vif.c[lane];
                    before_ap.write(txn);
                end
                if (vif.rst_n && vif.out_valid[lane] && vif.out_ready[lane]) begin
                    txn = fpu_datapath_txn::type_id::create("result_txn");
                    txn.lane   = lane[0];
                    txn.thrd   = vif.out_thrd[lane];
                    txn.result = vif.result[lane];
                    after_ap.write(txn);
                end
            end
        end
    endtask: run_phase
endclass: fpu_datapath_mon
