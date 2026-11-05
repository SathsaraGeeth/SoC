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

class sram_bank_cov extends uvm_subscriber #(sram_bank_txn);
    `uvm_component_utils(sram_bank_cov)

    bit we;
    bit lr;
    bit sc;
    bit sc_succ;

    covergroup sram_bank_cg;
        cp_we:      coverpoint we;
        cp_lr:      coverpoint lr;
        cp_sc:      coverpoint sc;
        cp_sc_succ: coverpoint sc_succ;
        cross cp_sc, cp_sc_succ;
    endgroup

    function new(string name = "sram_bank_cov", uvm_component parent = null);
        super.new(name, parent);
        sram_bank_cg = new();
    endfunction

    function void write(sram_bank_txn txn);
        we      = txn.we;
        lr      = txn.lr;
        sc      = txn.sc;
        sc_succ = txn.sc_succ;
        sram_bank_cg.sample();
    endfunction
endclass: sram_bank_cov

