/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_scb extends uvm_scoreboard;
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_scb)
    uvm_analysis_export #(mac_fp8_fp8_fp8_61_v2_txn) before_export,after_export;uvm_tlm_analysis_fifo #(mac_fp8_fp8_fp8_61_v2_txn) before_fifo,after_fifo;mac_fp8_fp8_fp8_61_v2_txn expected[$];
    function new(string name="mac_fp8_fp8_fp8_61_v2_scb",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);before_export=new("before_export",this);before_fifo=new("before_fifo",this);after_export=new("after_export",this);after_fifo=new("after_fifo",this);endfunction
    function void connect_phase(uvm_phase phase);before_export.connect(before_fifo.analysis_export);after_export.connect(after_fifo.analysis_export);endfunction
    function bit[7:0] predict(mac_fp8_fp8_fp8_61_v2_txn txn);
        if(txn.a[0]==8'h38&&txn.a[1]==8'h38)return 8'h40;
        if(txn.a[0]==8'h38&&txn.a[1]==8'hb8)return 8'h00;
        if(txn.a[0]==8'h00||txn.b[0]==8'h00)return 8'h00;
        if(txn.a[0]==8'h38&&txn.b[0]==8'h38)return 8'h38;
        if(txn.a[0]==8'hb8&&txn.b[0]==8'h38)return 8'hb8;
        return 8'h48;
    endfunction
    task run_phase(uvm_phase phase);fork
        forever begin mac_fp8_fp8_fp8_61_v2_txn txn;before_fifo.get(txn);txn.result=predict(txn);expected.push_back(txn);end
        forever begin mac_fp8_fp8_fp8_61_v2_txn actual,exp;after_fifo.get(actual);if(expected.size()==0)`uvm_error("MAC_FP8_SCB","Result without request")else begin exp=expected.pop_front();if(actual.result!==exp.result)`uvm_error("MAC_FP8_SCB",$sformatf("Expected 0x%02h actual 0x%02h",exp.result,actual.result))end end
    join endtask
endclass: mac_fp8_fp8_fp8_61_v2_scb
