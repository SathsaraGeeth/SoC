/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import uvm_pkg::*;
import core_pkg::*;
`include "uvm_macros.svh"

class alu_txn extends uvm_sequence_item;
    rand bit               lane;
    rand isa_pkg::alu_op_e op;
    rand bit [XLEN-1:0]    a;
    rand bit [XLEN-1:0]    b;
    rand bit [XLEN-1:0]    pc;
    rand bit [XLEN-1:0]    imm;
    rand bit               use_imm;
    rand bit               use_pc;
    rand bit               word_op;
    rand bit [3:0]         control_kind;
    rand bit [2:0]         funct3;
    rand bit [$clog2(NUM_HW_THRDS)-1:0] thrd_id;
    bit [XLEN-1:0]         result;
    bit [XLEN-1:0]         br_target;
    bit                    br_taken;

    constraint c_control {
        control_kind dist {0 := 82, 1 := 10, 2 := 6, 3 := 2};
        if (control_kind != 0) {
            op == isa_pkg::ALU_ADD;
            word_op == 1'b0;
            use_imm == 1'b1;
        }
        if (control_kind == 1)
            funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
    }

    `uvm_object_utils_begin(alu_txn)
        `uvm_field_int(lane, UVM_ALL_ON)
        `uvm_field_enum(isa_pkg::alu_op_e, op, UVM_ALL_ON)
        `uvm_field_int(a, UVM_ALL_ON)
        `uvm_field_int(b, UVM_ALL_ON)
        `uvm_field_int(pc, UVM_ALL_ON)
        `uvm_field_int(imm, UVM_ALL_ON)
        `uvm_field_int(use_imm, UVM_ALL_ON)
        `uvm_field_int(use_pc, UVM_ALL_ON)
        `uvm_field_int(word_op, UVM_ALL_ON)
        `uvm_field_int(control_kind, UVM_ALL_ON)
        `uvm_field_int(funct3, UVM_ALL_ON)
        `uvm_field_int(thrd_id, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "alu_txn");
        super.new(name);
    endfunction
endclass: alu_txn

