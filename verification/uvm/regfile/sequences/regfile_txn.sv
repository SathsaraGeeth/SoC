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

class regfile_txn extends uvm_sequence_item;
    rand bit                            we;
    rand bit [$clog2(REG_COUNT)-1:0]    rs1_addr;
    rand bit [$clog2(REG_COUNT)-1:0]    rs2_addr;
    rand bit [$clog2(REG_COUNT)-1:0]    rs3_addr;
    rand bit [$clog2(NUM_HW_THRDS)-1:0] rthrd_id;
    rand bit [$clog2(REG_COUNT)-1:0]    rd_addr;
    rand bit [$clog2(NUM_HW_THRDS)-1:0] wthrd_id;
    rand bit [XLEN-1:0]                 rd_wdata;
    bit [XLEN-1:0]                      rs1_data;
    bit [XLEN-1:0]                      rs2_data;
    bit [XLEN-1:0]                      rs3_data;

    constraint c_write {
        we dist {1'b0 := 45, 1'b1 := 55};
    }

    `uvm_object_utils_begin(regfile_txn)
        `uvm_field_int(we, UVM_ALL_ON)
        `uvm_field_int(rs1_addr, UVM_ALL_ON)
        `uvm_field_int(rs2_addr, UVM_ALL_ON)
        `uvm_field_int(rs3_addr, UVM_ALL_ON)
        `uvm_field_int(rthrd_id, UVM_ALL_ON)
        `uvm_field_int(rd_addr, UVM_ALL_ON)
        `uvm_field_int(wthrd_id, UVM_ALL_ON)
        `uvm_field_int(rd_wdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "regfile_txn");
        super.new(name);
    endfunction
endclass: regfile_txn

