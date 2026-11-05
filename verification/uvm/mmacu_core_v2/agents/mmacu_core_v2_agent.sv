/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_agent extends uvm_agent;
    `uvm_component_utils(mmacu_core_v2_agent)
    mmacu_core_v2_seqr seqr; mmacu_core_v2_drv drv; mmacu_core_v2_mon mon;
    uvm_analysis_port #(mmacu_core_v2_txn) after_ap;
    function new(string name="mmacu_core_v2_agent",uvm_component parent=null);super.new(name,parent);after_ap=new("after_ap",this);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);seqr=mmacu_core_v2_seqr::type_id::create("seqr",this);drv=mmacu_core_v2_drv::type_id::create("drv",this);mon=mmacu_core_v2_mon::type_id::create("mon",this);endfunction
    function void connect_phase(uvm_phase phase);drv.seq_item_port.connect(seqr.seq_item_export);mon.after_ap.connect(after_ap);endfunction
endclass: mmacu_core_v2_agent

