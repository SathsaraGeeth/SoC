/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_mon extends uvm_monitor;
    `uvm_component_utils(sys_address_generator_mon)
    virtual sys_address_generator_if vif;
    uvm_analysis_port #(sys_address_generator_txn) before_ap;
    uvm_analysis_port #(sys_address_generator_txn) after_ap;
    function new(string name = "sys_address_generator_mon", uvm_component parent = null);
        super.new(name, parent); before_ap = new("before_ap", this); after_ap = new("after_ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sys_address_generator_if)::get(this, "", "vif", vif))
            `uvm_fatal("SYS_ADDR_MON", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        sys_address_generator_txn txn;
        forever begin
            @(posedge vif.clk);
            for (int kind = 0; kind < 3; kind++) begin
                if (vif.rst_n && vif.start[kind]) begin
                    txn = sys_address_generator_txn::type_id::create("request_txn");
                    txn.kind = kind[1:0]; txn.tid = vif.tid[kind]; txn.base_addr = vif.base_addr[kind];
                    txn.a_tiles = vif.a_tiles[kind]; txn.b_tiles = vif.b_tiles[kind];
                    txn.dense = vif.dense[kind]; txn.cmd_start = vif.cmd_start[kind];
                    txn.cmd_last = vif.cmd_last[kind]; txn.mac_type = vif.mac_type[kind];
                    before_ap.write(txn);
                end
                if (vif.rst_n && vif.valid[kind] && vif.ready[kind]) begin
                    txn = sys_address_generator_txn::type_id::create("entry_txn");
                    txn.kind = kind[1:0]; txn.data = vif.data[kind];
                    after_ap.write(txn);
                end
            end
        end
    endtask
endclass: sys_address_generator_mon
