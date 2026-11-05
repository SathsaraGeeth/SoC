/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mac20i_v2_txn extends uvm_sequence_item;
    rand bit [1:0] terms;
    rand bit signed [7:0] a[3];
    rand bit signed [7:0] b[3];
    rand bit insert_stall;
    bit [7:0] result;
    constraint c_terms { terms inside {[1:3]}; }
    `uvm_object_utils_begin(mac20i_v2_txn)
        `uvm_field_int(terms, UVM_ALL_ON)
        `uvm_field_sarray_int(a, UVM_ALL_ON)
        `uvm_field_sarray_int(b, UVM_ALL_ON)
        `uvm_field_int(insert_stall, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name = "mac20i_v2_txn"); super.new(name); endfunction
endclass: mac20i_v2_txn
