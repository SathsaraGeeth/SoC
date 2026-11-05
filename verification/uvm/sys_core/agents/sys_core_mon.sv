/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_mon extends uvm_monitor;
 `uvm_component_utils(sys_core_mon) virtual sys_core_if vif;uvm_analysis_port#(sys_core_txn) after_ap;logic stalled;logic[63:0] stalled_data;
 function new(string name="sys_core_mon",uvm_component parent=null);super.new(name,parent);after_ap=new("after_ap",this);endfunction
 function void build_phase(uvm_phase phase);super.build_phase(phase);if(!uvm_config_db#(virtual sys_core_if)::get(this,"","vif",vif))`uvm_fatal("SYS_MON","Virtual interface not set")endfunction
 task run_phase(uvm_phase phase);sys_core_txn t;forever begin @(posedge vif.clk);if(!vif.rst_n)stalled=0;else begin
   if(stalled&&(!vif.mmio_resp_valid||vif.mmio_resp_rdata!==stalled_data))`uvm_error("SYS_MON","Stalled response changed")
   stalled=vif.mmio_resp_valid&&!vif.mmio_resp_ready;stalled_data=vif.mmio_resp_rdata;
   if(vif.mmio_req_valid&&vif.mmio_req_ready)begin t=sys_core_txn::type_id::create("req");t.offset=vif.mmio_req_addr[7:0];t.data=vif.mmio_req_wdata;t.mask=vif.mmio_req_wmask;t.host=vif.host_thrd;after_ap.write(t);end
   if(vif.mmio_resp_valid&&vif.mmio_resp_ready)begin t=sys_core_txn::type_id::create("resp");t.response=1;t.rdata=vif.mmio_resp_rdata;after_ap.write(t);end
 end end endtask
endclass: sys_core_mon

