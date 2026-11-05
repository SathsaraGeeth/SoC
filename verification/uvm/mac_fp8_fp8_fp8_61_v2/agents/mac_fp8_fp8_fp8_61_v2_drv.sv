/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_drv extends uvm_driver #(mac_fp8_fp8_fp8_61_v2_txn);
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_drv)
    virtual mac_fp8_fp8_fp8_61_v2_if vif;
    function new(string name = "mac_fp8_fp8_fp8_61_v2_drv", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual mac_fp8_fp8_fp8_61_v2_if)::get(this,"","vif",vif)) `uvm_fatal("MAC_FP8_DRV","Virtual interface not set") endfunction
    task run_phase(uvm_phase phase);
        mac_fp8_fp8_fp8_61_v2_txn txn; wait(vif.rst_n===1'b1);
        forever begin seq_item_port.get_next_item(txn);
            for(int term=0;term<txn.terms;term++) begin
                if(txn.insert_stall&&term==1) begin @(negedge vif.clk); vif.en<=0; @(negedge vif.clk); vif.en<=1; end
                @(negedge vif.clk); vif.a<=txn.a[term]; vif.b<=txn.b[term]; vif.start<=term==0; vif.last<=term+1==txn.terms;
            end
            @(negedge vif.clk); vif.start<=0; vif.last<=0; vif.a<=0; vif.b<=0;
            while(!vif.done) @(negedge vif.clk); repeat(2) @(negedge vif.clk); seq_item_port.item_done();
        end
    endtask
endclass: mac_fp8_fp8_fp8_61_v2_drv
