/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mac20i_v2_seq extends uvm_sequence #(mac20i_v2_txn);
    `uvm_object_utils(mac20i_v2_seq)
    function new(string name = "mac20i_v2_seq"); super.new(name); endfunction
    virtual task body();
        mac20i_v2_txn txn;
        repeat (160) begin
            txn = mac20i_v2_txn::type_id::create("txn"); start_item(txn);
            assert (txn.randomize()) else `uvm_error("MAC20I_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask
endclass: mac20i_v2_seq
