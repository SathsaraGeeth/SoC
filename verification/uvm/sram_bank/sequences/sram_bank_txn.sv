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
import memory_pkg::*;
`include "uvm_macros.svh"

class sram_bank_txn extends uvm_sequence_item;
    rand bit                         we;
    rand bit                         lr;
    rand bit                         sc;
    rand bit [BANK_ADDR_W-1:0]       addr;
    rand bit [BANK_WORD_W/8-1:0]     wstrb;
    rand bit [XLEN-1:0]              wdata;
    rand bit [PORT_IDX_W-1:0]        port;
    rand bit [THRD_W-1:0]            thrd;
    rand int unsigned                stall_cycles;
    bit                              sc_succ;
    bit [XLEN-1:0]                   rdata;
    bit [PORT_IDX_W-1:0]             resp_port;
    bit [THRD_W-1:0]                 resp_thrd;

    constraint c_legal {
        !(lr && sc);
        if (lr) {
            !we;
            wstrb != '0;
        }
        if (sc) {
            we;
            wstrb != '0;
        }
        if (!we && !lr)
            wstrb == '0;
        stall_cycles inside {[0:3]};
    }

    `uvm_object_utils_begin(sram_bank_txn)
        `uvm_field_int(we, UVM_ALL_ON)
        `uvm_field_int(lr, UVM_ALL_ON)
        `uvm_field_int(sc, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(port, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_int(stall_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "sram_bank_txn");
        super.new(name);
    endfunction
endclass: sram_bank_txn
