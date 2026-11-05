/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_seq extends uvm_sequence #(sys_address_generator_txn);
    `uvm_object_utils(sys_address_generator_seq)
    function new(string name = "sys_address_generator_seq"); super.new(name); endfunction
    virtual task body();
        sys_address_generator_txn txn;
        repeat (36) begin
            txn = sys_address_generator_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else `uvm_error("SYS_ADDR_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask
endclass: sys_address_generator_seq
