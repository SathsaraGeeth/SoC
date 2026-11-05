/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_txn extends uvm_sequence_item;
    rand bit [2:0] case_id; rand bit insert_stall;
    bit [3:0] terms; bit [7:0] a[8]; bit [7:0] b[8]; bit [7:0] result;
    constraint c_case { case_id inside {[0:5]}; }
    `uvm_object_utils_begin(mac_fp8_fp8_fp8_61_v2_txn)
        `uvm_field_int(case_id, UVM_ALL_ON) `uvm_field_int(insert_stall, UVM_ALL_ON)
        `uvm_field_int(terms, UVM_ALL_ON) `uvm_field_sarray_int(a, UVM_ALL_ON)
        `uvm_field_sarray_int(b, UVM_ALL_ON) `uvm_field_int(result, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name = "mac_fp8_fp8_fp8_61_v2_txn"); super.new(name); endfunction
    function void post_randomize();
        terms = 8; result = 0;
        foreach (a[i]) begin a[i] = 8'h00; b[i] = 8'h38; end
        unique case (case_id)
            1: begin a[0]=8'h38; b[0]=8'h38; result=8'h38; end
            2: begin a[0]=8'hb8; b[0]=8'h38; result=8'hb8; end
            3: begin a[0]=8'h38; b[0]=8'h38; a[1]=8'h38; b[1]=8'h38; result=8'h40; end
            4: begin a[0]=8'h38; b[0]=8'h38; a[1]=8'hb8; b[1]=8'h38; result=8'h00; end
            5: begin a[0]=8'h40; b[0]=8'h40; result=8'h48; end
            default: begin end
        endcase
    endfunction
endclass: mac_fp8_fp8_fp8_61_v2_txn
