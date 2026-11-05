/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
import fpu_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_drv extends uvm_driver #(fpu_datapath_txn);
    `uvm_component_utils(fpu_datapath_drv)

    virtual fpu_datapath_if vif;

    function new(string name = "fpu_datapath_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_datapath_if)::get(this, "", "vif", vif))
            `uvm_fatal("FPU_DP_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fpu_datapath_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            while (!vif.in_ready[txn.lane])
                @(negedge vif.clk);
            vif.op[txn.lane]         <= txn.op;
            vif.a_fmt[txn.lane]      <= OP_FMT_FP32;
            vif.b_fmt[txn.lane]      <= OP_FMT_FP32;
            vif.c_fmt[txn.lane]      <= OP_FMT_FP32;
            vif.result_fmt[txn.lane] <= FMT_FP32;
            vif.in_thrd[txn.lane]    <= txn.thrd;
            vif.a[txn.lane]          <= txn.a;
            vif.b[txn.lane]          <= txn.b;
            vif.c[txn.lane]          <= txn.c;
            vif.in_valid[txn.lane]   <= 1'b1;
            @(negedge vif.clk);
            vif.in_valid[txn.lane]   <= 1'b0;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: fpu_datapath_drv
