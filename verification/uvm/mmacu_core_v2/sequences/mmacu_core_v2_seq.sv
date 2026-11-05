/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mmacu_core_v2_seq extends uvm_sequence #(mmacu_core_v2_txn);
    `uvm_object_utils(mmacu_core_v2_seq)
    function new(string name="mmacu_core_v2_seq"); super.new(name); endfunction
    virtual task body();
        mmacu_core_v2_txn txn;
        repeat (6) begin
            txn = mmacu_core_v2_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else `uvm_error("MMACU_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask
endclass: mmacu_core_v2_seq

