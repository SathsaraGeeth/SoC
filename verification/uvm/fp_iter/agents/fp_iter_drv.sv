/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
import fpu_pkg::*;
`include "uvm_macros.svh"

class fp_iter_drv extends uvm_driver #(fp_iter_txn);
    `uvm_component_utils(fp_iter_drv)

    virtual fp_iter_if vif;

    function new(string name = "fp_iter_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fp_iter_if)::get(this, "", "vif", vif))
            `uvm_fatal("FP_ITER_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fp_iter_txn txn;
        int lane;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            lane = txn.kind[0];
            @(negedge vif.clk);
            if (txn.kind < 2) begin
                vif.p_out_thrd[lane] <= txn.thrd;
                vif.p_result[lane]   <= txn.bypass_result;
                vif.p_out_valid[lane] <= 1'b1;
                @(negedge vif.clk);
                vif.p_out_valid[lane] <= 1'b0;
            end else begin
                while (!vif.l_in_ready[1])
                    @(negedge vif.clk);
                vif.l_op[1]          <= txn.kind == 2 ? DIV : SQRT;
                vif.l_in_thrd[1]     <= txn.thrd;
                vif.l_a[1]           <= txn.kind == 2
                                     ? 64'h0000_0000_3f80_0000
                                     : 64'h0000_0000_bf80_0000;
                vif.l_b[1]           <= txn.kind == 2
                                     ? 64'h0000_0000_0000_0000 : '0;
                vif.l_in_valid[1]    <= 1'b1;
                @(negedge vif.clk);
                vif.l_in_valid[1]    <= 1'b0;
                while (!vif.l_out_valid[1])
                    @(negedge vif.clk);
            end
            seq_item_port.item_done();
        end
    endtask
endclass: fp_iter_drv
