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

class regfile_cov extends uvm_subscriber #(regfile_txn);
    `uvm_component_utils(regfile_cov)

    bit                            we;
    bit [$clog2(REG_COUNT)-1:0]    rd_addr;
    bit [$clog2(NUM_HW_THRDS)-1:0] rthrd_id;
    bit [$clog2(NUM_HW_THRDS)-1:0] wthrd_id;

    covergroup regfile_cg;
        cp_we:       coverpoint we;
        cp_rd:       coverpoint rd_addr {
            bins x0   = {0};
            bins regs = {[1:REG_COUNT-1]};
        }
        cp_rthread:  coverpoint rthrd_id;
        cp_wthread:  coverpoint wthrd_id;
        cross cp_we, cp_rd;
        cross cp_rthread, cp_wthread;
    endgroup

    function new(string name = "regfile_cov", uvm_component parent = null);
        super.new(name, parent);
        regfile_cg = new();
    endfunction

    function void write(regfile_txn txn);
        we        = txn.we;
        rd_addr   = txn.rd_addr;
        rthrd_id  = txn.rthrd_id;
        wthrd_id  = txn.wthrd_id;
        regfile_cg.sample();
    endfunction
endclass: regfile_cov

