/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_cov extends uvm_subscriber #(mmacu_core_v2_txn);
    `uvm_component_utils(mmacu_core_v2_cov)
    bit output_event,start,end_tile;
    covergroup cg; cp_kind:coverpoint output_event; cp_start:coverpoint start; cp_end:coverpoint end_tile; endgroup
    function new(string name="mmacu_core_v2_cov",uvm_component parent=null);super.new(name,parent);cg=new();endfunction
    function void write(mmacu_core_v2_txn txn);output_event=txn.output_event;start=txn.start;end_tile=txn.end_tile;cg.sample();endfunction
endclass: mmacu_core_v2_cov

