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

class circular_buffer_txn extends uvm_sequence_item;
    rand bit       enq_valid;
    rand bit       deq_valid;
    rand bit [7:0] data;
    rand bit       do_clear;
    bit            rst_n;
    bit            clr_n;
    bit            enq_ready;
    bit            deq_ready;
    bit            pre_enq_ready;
    bit            pre_deq_ready;
    bit [7:0]      head_data;
    bit            full;
    bit            empty;
    bit [3:0]      level;

    constraint c_clear {
        do_clear dist {1'b0 := 98, 1'b1 := 2};
    }

    `uvm_object_utils_begin(circular_buffer_txn)
        `uvm_field_int(enq_valid, UVM_ALL_ON)
        `uvm_field_int(deq_valid, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(do_clear, UVM_ALL_ON)
        `uvm_field_int(level, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "circular_buffer_txn");
        super.new(name);
    endfunction
endclass: circular_buffer_txn
