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
`include "uvm_macros.svh"

class sys_common_txn extends uvm_sequence_item;
    rand bit en;
    rand bit clr_n;
    rand bit start;
    rand bit sel;
    rand bit [7:0] data0;
    rand bit [7:0] data1;
    rand bit [2:0] ptr;
    rand bit [7:0] target;
    bit [7:0] reg_out;
    bit [7:0] mux_out;
    bit [7:0] pipe_out;
    bit [15:0] mul_out;
    bit [15:0] add_out;
    bit [7:0] pipev_out;
    bit done;

    constraint c_legal {
        ptr inside {[0:4]};
        clr_n dist {1'b1 := 92, 1'b0 := 8};
        en dist {1'b1 := 80, 1'b0 := 20};
        start dist {1'b0 := 92, 1'b1 := 8};
        target inside {[0:24]};
    }

    `uvm_object_utils_begin(sys_common_txn)
        `uvm_field_int(en, UVM_ALL_ON)
        `uvm_field_int(clr_n, UVM_ALL_ON)
        `uvm_field_int(start, UVM_ALL_ON)
        `uvm_field_int(sel, UVM_ALL_ON)
        `uvm_field_int(data0, UVM_ALL_ON)
        `uvm_field_int(data1, UVM_ALL_ON)
        `uvm_field_int(ptr, UVM_ALL_ON)
        `uvm_field_int(target, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "sys_common_txn");
        super.new(name);
    endfunction
endclass: sys_common_txn

