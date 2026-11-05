/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
import isa_pkg::*;
`include "uvm_macros.svh"

class fp_iter_txn extends uvm_sequence_item;
    rand bit [1:0]      kind;
    rand bit [XLEN-1:0] thrd;
    rand bit [XLEN-1:0] bypass_result;
    bit [XLEN-1:0]      result;

    constraint c_tag { thrd[XLEN-1:4] != '1; }

    `uvm_object_utils_begin(fp_iter_txn)
        `uvm_field_int(kind, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_int(bypass_result, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fp_iter_txn");
        super.new(name);
    endfunction
endclass: fp_iter_txn
