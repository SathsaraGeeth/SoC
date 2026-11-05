/* 
 * verification/uvm/isa/commit_monitor.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

`include "uvm_macros.svh"

import uvm_pkg::*;
import core_pkg::*;

class commit_monitor extends uvm_monitor;
    `uvm_component_utils(commit_monitor)

    virtual commit_if           vif;
    uvm_analysis_port #(txn)    ap;

    protected int unsigned      commit_id_counter = 0;

    function new (string name = "commit_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual commit_if)::get(this, "", "vif", vif))
            `uvm_fatal("CORE_ARCH_COMMIT_MON", "Could not get viface")
    endfunction

    task run_phase(uvm_phase phase);
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            automatic int thread_idx = t;
            fork
                forever begin
                    @(posedge vif.clk);
                    if (vif.rst_n) begin
                        if (vif.commit_valid[thread_idx]) begin
                            monitor_instruction_commit(thread_idx);
                        end
                        if (vif.rf_we[thread_idx]) begin
                            monitor_register_write(thread_idx);
                        end
                        if (vif.csr_we[thread_idx]) begin
                            monitor_csr_write(thread_idx);
                        end
                        if (vif.mem_req_we[thread_idx]) begin
                            monitor_memory_write(thread_idx);
                        end
                    end
                end
            join_none
        end
        wait fork;
    endtask

    function void monitor_instruction_commit(int unsigned t);
        pc_txn txn    = pc_txn::type_id::create("pc_txn");
        txn.thrd_id   = t;
        txn.pc        = vif.commit_pc[t];
        txn.commit_id = ++commit_id_counter;
        ap.write(txn);
    endfunction

    function void monitor_register_write(int unsigned t);
        rf_txn txn    = rf_txn::type_id::create("rf_txn");
        txn.thrd_id   = t;
        txn.pc        = vif.rf_pc[t];
        txn.waddr     = vif.rf_we_addr[t];
        txn.wdata     = vif.rf_we_data[t];
        txn.commit_id = ++commit_id_counter;
        ap.write(txn);
    endfunction

    function void monitor_csr_write(int unsigned t);
        csr_txn txn   = csr_txn::type_id::create("csr_txn");
        txn.thrd_id   = t;
        txn.pc        = vif.csr_pc[t];
        txn.waddr     = vif.csr_we_addr[t];
        txn.wdata     = vif.csr_we_data[t];
        txn.commit_id = ++commit_id_counter;
        ap.write(txn);
    endfunction

    function void monitor_memory_write(int unsigned t);
        mem_txn txn   = mem_txn::type_id::create("mem_txn");
        txn.thrd_id   = t;
        txn.pc        = vif.mem_pc[t];
        txn.waddr     = vif.mem_req_addr[t];
        txn.wdata     = vif.mem_req_wdata[t];
        txn.wmask     = vif.mem_req_wmask[t];
        txn.commit_id = ++commit_id_counter;
        ap.write(txn);
    endfunction

endclass: commit_monitor
