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

class memory_txn extends uvm_sequence_item;
    rand bit we;
    rand int unsigned port;
    rand bit [memory_pkg::THRD_W-1:0] thrd;
    rand bit [memory_pkg::VIR_ADDR_W-1:0] addr;
    rand bit [memory_pkg::XLEN-1:0] wdata;
    rand bit [memory_pkg::XLEN/8-1:0] wstrb;
    bit [memory_pkg::XLEN-1:0] rdata;
    bit [memory_pkg::THRD_W-1:0] resp_thrd;

    constraint c_legal {
        port < memory_pkg::NUM_RW_PORTS;
        addr inside {[0:2047]};
        if (we)
            wstrb == '1;
        else
            wstrb == '0;
    }

    `uvm_object_utils_begin(memory_txn)
        `uvm_field_int(we, UVM_ALL_ON)
        `uvm_field_int(port, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "memory_txn");
        super.new(name);
    endfunction
endclass: memory_txn

