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

class timer_txn extends uvm_sequence_item;
    rand bit        we;
    rand bit [1:0]  word;
    rand bit [7:0]  wstrb;
    rand bit [63:0] wdata;
    rand int unsigned backpressure;
    bit             rst_n;
    bit             req_valid;
    bit             req_ready;
    bit             pre_req_ready;
    bit             resp_valid;
    bit             resp_ready;
    bit [63:0]      rdata;
    bit             irq;

    constraint c_write {
        we dist {1'b0 := 55, 1'b1 := 45};
        backpressure inside {[0:4]};
        if (!we)
            wstrb == '0;
    }

    `uvm_object_utils_begin(timer_txn)
        `uvm_field_int(we, UVM_ALL_ON)
        `uvm_field_int(word, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(backpressure, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "timer_txn");
        super.new(name);
    endfunction
endclass: timer_txn

