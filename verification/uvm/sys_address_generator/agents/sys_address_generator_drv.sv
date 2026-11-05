/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_drv extends uvm_driver #(sys_address_generator_txn);
    `uvm_component_utils(sys_address_generator_drv)
    virtual sys_address_generator_if vif;
    function new(string name = "sys_address_generator_drv", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sys_address_generator_if)::get(this, "", "vif", vif))
            `uvm_fatal("SYS_ADDR_DRV", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        sys_address_generator_txn txn;
        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.tid[txn.kind]       <= txn.tid;
            vif.base_addr[txn.kind] <= txn.base_addr;
            vif.a_tiles[txn.kind]   <= txn.a_tiles;
            vif.b_tiles[txn.kind]   <= txn.b_tiles;
            vif.dense[txn.kind]     <= txn.dense;
            vif.cmd_start[txn.kind] <= txn.cmd_start;
            vif.cmd_last[txn.kind]  <= txn.cmd_last;
            vif.mac_type[txn.kind]  <= txn.mac_type;
            vif.start[txn.kind]     <= 1'b1;
            @(negedge vif.clk);
            vif.start[txn.kind]     <= 1'b0;
            while (!vif.done[txn.kind]) begin
                vif.ready[txn.kind] <= $urandom_range(0, 99) < 70;
                @(negedge vif.clk);
            end
            vif.ready[txn.kind] <= 1'b1;
            seq_item_port.item_done();
        end
    endtask
endclass: sys_address_generator_drv
