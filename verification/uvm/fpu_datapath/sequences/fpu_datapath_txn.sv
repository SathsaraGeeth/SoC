/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
import fpu_pkg::*;
import isa_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_txn extends uvm_sequence_item;
    rand bit              lane;
    rand bit [1:0]        case_id;
    rand bit [XLEN-1:0]   thrd;
    fp_op_e               op;
    bit [XLEN-1:0]        a;
    bit [XLEN-1:0]        b;
    bit [XLEN-1:0]        c;
    bit [XLEN-1:0]        result;

    `uvm_object_utils_begin(fpu_datapath_txn)
        `uvm_field_int(lane, UVM_ALL_ON)
        `uvm_field_int(case_id, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_enum(fp_op_e, op, UVM_ALL_ON)
        `uvm_field_int(a, UVM_ALL_ON)
        `uvm_field_int(b, UVM_ALL_ON)
        `uvm_field_int(c, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fpu_datapath_txn");
        super.new(name);
    endfunction

    function void post_randomize();
        unique case (case_id)
            2'd0: begin
                op = ADD;
                a  = 64'h0000_0000_3fc0_0000;
                b  = '0;
                c  = 64'h0000_0000_4010_0000;
            end
            2'd1: begin
                op = SUB;
                a  = 64'h0000_0000_4080_0000;
                b  = '0;
                c  = 64'h0000_0000_3fc0_0000;
            end
            2'd2: begin
                op = MUL;
                a  = 64'h0000_0000_3fc0_0000;
                b  = 64'h0000_0000_4000_0000;
                c  = '0;
            end
            default: begin
                op = FMA;
                a  = 64'h0000_0000_3fc0_0000;
                b  = 64'h0000_0000_4000_0000;
                c  = 64'h0000_0000_3f80_0000;
            end
        endcase
    endfunction: post_randomize
endclass: fpu_datapath_txn
