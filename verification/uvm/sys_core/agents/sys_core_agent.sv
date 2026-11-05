/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;`include "uvm_macros.svh"
class sys_core_agent extends uvm_agent;`uvm_component_utils(sys_core_agent)sys_core_seqr seqr;sys_core_drv drv;sys_core_mon mon;uvm_analysis_port#(sys_core_txn)after_ap;
function new(string name="sys_core_agent",uvm_component parent=null);super.new(name,parent);after_ap=new("after_ap",this);endfunction
function void build_phase(uvm_phase p);super.build_phase(p);seqr=sys_core_seqr::type_id::create("seqr",this);drv=sys_core_drv::type_id::create("drv",this);mon=sys_core_mon::type_id::create("mon",this);endfunction
function void connect_phase(uvm_phase p);drv.seq_item_port.connect(seqr.seq_item_export);mon.after_ap.connect(after_ap);endfunction endclass

