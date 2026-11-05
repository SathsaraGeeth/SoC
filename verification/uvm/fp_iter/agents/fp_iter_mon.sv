/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
import fpu_pkg::*;
import isa_pkg::*;
`include "uvm_macros.svh"

class fp_iter_mon extends uvm_monitor;
    `uvm_component_utils(fp_iter_mon)

    virtual fp_iter_if vif;
    uvm_analysis_port #(fp_iter_txn) before_ap;
    uvm_analysis_port #(fp_iter_txn) after_ap;

    function new(string name = "fp_iter_mon", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap  = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fp_iter_if)::get(this, "", "vif", vif))
            `uvm_fatal("FP_ITER_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fp_iter_txn txn;

        forever begin
            @(posedge vif.clk);
            for (int lane = 0; lane < 2; lane++) begin
                if (vif.rst_n && vif.p_out_valid[lane]
                 && vif.p_out_thrd[lane][XLEN-1:4] != '1) begin
                    txn = fp_iter_txn::type_id::create("bypass_txn");
                    txn.kind          = lane[1:0];
                    txn.thrd          = vif.p_out_thrd[lane];
                    txn.bypass_result = vif.p_result[lane];
                    before_ap.write(txn);
                end
                if (vif.rst_n && vif.l_out_valid[lane]
                 && vif.l_out_ready[lane]) begin
                    txn = fp_iter_txn::type_id::create("result_txn");
                    txn.kind   = lane[1:0];
                    txn.thrd   = vif.l_out_thrd[lane];
                    txn.result = vif.l_result[lane];
                    after_ap.write(txn);
                end
            end
            if (vif.rst_n && vif.l_in_valid[1] && vif.l_in_ready[1]
             && (vif.l_op[1] == DIV || vif.l_op[1] == SQRT)) begin
                txn = fp_iter_txn::type_id::create("iter_txn");
                txn.kind = vif.l_op[1] == DIV ? 2 : 3;
                txn.thrd = vif.l_in_thrd[1];
                before_ap.write(txn);
            end
        end
    endtask
endclass: fp_iter_mon
