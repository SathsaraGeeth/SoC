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

class csr_txn extends uvm_sequence_item;
    rand bit [2:0]                        kind;
    rand bit [$clog2(CSR_COUNT)-1:0]      rd_addr;
    rand bit [$clog2(CSR_COUNT)-1:0]      rs_addr;
    rand bit [$clog2(NUM_HW_THRDS)-1:0]   thrd_id;
    rand bit [XLEN-1:0]                   wdata;
    rand bit [NUM_HW_THRDS-1:0]           irq_timer;
    rand bit                              trap_to_s;
    bit                                   rst_n;
    bit [XLEN-1:0]                        rdata;
    bit [isa_pkg::PRIV_MODE_W-1:0]        priv_mode;
    bit [XLEN-1:0]                        medeleg;
    bit [XLEN-1:0]                        mideleg;
    bit                                   irq_pending;

    constraint c_kind {
        kind dist {0 := 65, 1 := 12, 2 := 8, 3 := 8, 4 := 7};
        rd_addr < CSR_COUNT;
        rs_addr < CSR_COUNT;
    }

    `uvm_object_utils_begin(csr_txn)
        `uvm_field_int(kind, UVM_ALL_ON)
        `uvm_field_int(rd_addr, UVM_ALL_ON)
        `uvm_field_int(rs_addr, UVM_ALL_ON)
        `uvm_field_int(thrd_id, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(irq_timer, UVM_ALL_ON)
        `uvm_field_int(trap_to_s, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "csr_txn");
        super.new(name);
    endfunction
endclass: csr_txn

