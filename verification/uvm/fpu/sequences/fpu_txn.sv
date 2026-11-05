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

class fpu_txn extends uvm_sequence_item;
    rand isa_pkg::fpu_op_e op;
    rand bit [31:0]        a;
    rand bit [31:0]        b;
    rand bit [$clog2(NUM_HW_THRDS)-1:0] thrd_id;
    bit [XLEN-1:0]         result;

    constraint c_simple_op {
        op inside {
            isa_pkg::FPU_FSGNJ,
            isa_pkg::FPU_FSGNJN,
            isa_pkg::FPU_FSGNJX,
            isa_pkg::FPU_FCMP_EQ,
            isa_pkg::FPU_FCMP_LT,
            isa_pkg::FPU_FCMP_LE,
            isa_pkg::FPU_FMIN,
            isa_pkg::FPU_FMAX,
            isa_pkg::FPU_FCLASS
        };
    }

    `uvm_object_utils_begin(fpu_txn)
        `uvm_field_enum(isa_pkg::fpu_op_e, op, UVM_ALL_ON)
        `uvm_field_int(a, UVM_ALL_ON)
        `uvm_field_int(b, UVM_ALL_ON)
        `uvm_field_int(thrd_id, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fpu_txn");
        super.new(name);
    endfunction
endclass: fpu_txn

