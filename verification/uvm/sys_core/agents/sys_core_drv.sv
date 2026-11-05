/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_drv extends uvm_driver #(sys_core_txn);
 `uvm_component_utils(sys_core_drv) virtual sys_core_if vif;
 function new(string name="sys_core_drv",uvm_component parent=null);super.new(name,parent);endfunction
 function void build_phase(uvm_phase phase);super.build_phase(phase);if(!uvm_config_db#(virtual sys_core_if)::get(this,"","vif",vif))`uvm_fatal("SYS_DRV","Virtual interface not set")endfunction
 task run_phase(uvm_phase phase);sys_core_txn t;int cycles;wait(vif.rst_n===1);forever begin
   seq_item_port.get_next_item(t);repeat(t.idle_cycles)@(negedge vif.clk);cycles=0;
   do begin @(negedge vif.clk);cycles++;if(cycles==100)`uvm_fatal("SYS_DRV","MMIO request timeout") end while(!vif.mmio_req_ready);
   vif.mmio_req_addr<=t.offset;vif.mmio_req_wdata<=t.data;vif.mmio_req_wmask<=t.mask;vif.host_thrd<=t.host;vif.mmio_req_valid<=1;
   @(negedge vif.clk);vif.mmio_req_valid<=0;vif.mmio_resp_ready<=0;repeat(t.backpressure)@(negedge vif.clk);vif.mmio_resp_ready<=1;
   cycles=0;while(!vif.mmio_resp_valid)begin @(negedge vif.clk);cycles++;if(cycles==100)`uvm_fatal("SYS_DRV","MMIO response timeout")end
   @(negedge vif.clk);vif.mmio_resp_ready<=0;seq_item_port.item_done();end endtask
endclass: sys_core_drv

