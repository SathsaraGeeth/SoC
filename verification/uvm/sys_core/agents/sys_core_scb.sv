/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_scb extends uvm_scoreboard;
 `uvm_component_utils(sys_core_scb) uvm_analysis_export#(sys_core_txn) after_export;uvm_tlm_analysis_fifo#(sys_core_txn) after_fifo;
 bit[255:0] cmd;int word_count;bit owned;bit[63:0] expected[$];bit compare_data[$];
 function new(string name="sys_core_scb",uvm_component parent=null);super.new(name,parent);endfunction
 function void build_phase(uvm_phase p);super.build_phase(p);after_export=new("after_export",this);after_fifo=new("after_fifo",this);endfunction
 function void connect_phase(uvm_phase p);after_export.connect(after_fifo.analysis_export);endfunction
 task run_phase(uvm_phase p);sys_core_txn t;bit[255:0] next_cmd;bit[63:0] value;forever begin after_fifo.get(t);if(!t.response)begin
   case(t.offset)8'h00:value=owned?64'h8:0;8'h10:value=0;default:value=0;endcase expected.push_back(value);compare_data.push_back(t.offset!=8'h10);
   if(t.offset==8'h08&&t.mask!=0)begin next_cmd={t.data,cmd[255:64]};cmd=next_cmd;if(word_count==3)begin word_count=0;if(next_cmd[31:24]==8'h03)owned=1;else if(next_cmd[31:24]==8'h04)owned=0;end else word_count++;end
 end else if(expected.size()==0)`uvm_error("SYS_SCB","Response without request") else begin value=expected.pop_front();if(compare_data.pop_front()&&t.rdata!==value)`uvm_error("SYS_SCB",$sformatf("MMIO mismatch expected=%h actual=%h",value,t.rdata));end end endtask
endclass: sys_core_scb
