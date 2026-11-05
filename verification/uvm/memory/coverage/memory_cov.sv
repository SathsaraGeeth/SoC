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

class memory_cov extends uvm_subscriber #(memory_txn);
    `uvm_component_utils(memory_cov)

    bit we;
    int unsigned port;
    bit [3:0] bank;

    covergroup memory_cg;
        cp_we:   coverpoint we;
        cp_port: coverpoint port {
            bins ports[] = {[0:memory_pkg::NUM_RW_PORTS-1]};
        }
        cp_bank: coverpoint bank;
        cross cp_we, cp_bank;
    endgroup

    function new(string name = "memory_cov", uvm_component parent = null);
        super.new(name, parent);
        memory_cg = new();
    endfunction

    function void write(memory_txn txn);
        we   = txn.we;
        port = txn.port;
        bank = (txn.addr >> $clog2(memory_pkg::XLEN/8)) %
               memory_pkg::NUM_BANKS;
        memory_cg.sample();
    endfunction
endclass: memory_cov

