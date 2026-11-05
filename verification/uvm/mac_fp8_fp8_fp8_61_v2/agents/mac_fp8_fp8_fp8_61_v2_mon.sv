/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_mon extends uvm_monitor;
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_mon)
    virtual mac_fp8_fp8_fp8_61_v2_if vif; uvm_analysis_port #(mac_fp8_fp8_fp8_61_v2_txn) before_ap,after_ap;
    function new(string name="mac_fp8_fp8_fp8_61_v2_mon",uvm_component parent=null);super.new(name,parent);before_ap=new("before_ap",this);after_ap=new("after_ap",this);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);if(!uvm_config_db#(virtual mac_fp8_fp8_fp8_61_v2_if)::get(this,"","vif",vif))`uvm_fatal("MAC_FP8_MON","Virtual interface not set")endfunction
    task run_phase(uvm_phase phase);
        mac_fp8_fp8_fp8_61_v2_txn txn,building;bit[1:0] pending;building=null;pending=0;
        fork
            forever begin @(posedge vif.clk);if(vif.rst_n&&vif.en)begin if(vif.start)begin building=mac_fp8_fp8_fp8_61_v2_txn::type_id::create("request_txn");building.terms=0;end if(building!=null)begin building.a[building.terms]=vif.a;building.b[building.terms]=vif.b;building.terms++;if(vif.last)begin before_ap.write(building);building=null;end end end end
            forever begin @(negedge vif.clk);if(pending[1])begin txn=mac_fp8_fp8_fp8_61_v2_txn::type_id::create("result_txn");txn.result=vif.d;after_ap.write(txn);end pending={pending[0],vif.rst_n&&vif.done};end
        join
    endtask
endclass: mac_fp8_fp8_fp8_61_v2_mon
