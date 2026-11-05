/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_seqr extends uvm_sequencer #(mmacu_core_v2_txn);
    `uvm_component_utils(mmacu_core_v2_seqr)
    function new(string name="mmacu_core_v2_seqr", uvm_component parent=null); super.new(name,parent); endfunction
endclass: mmacu_core_v2_seqr

