/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_seqr extends uvm_sequencer #(sys_core_txn);`uvm_component_utils(sys_core_seqr) function new(string name="sys_core_seqr",uvm_component parent=null);super.new(name,parent);endfunction endclass

