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

class memory_scb extends uvm_scoreboard;
    `uvm_component_utils(memory_scb)

    uvm_analysis_imp #(memory_txn, memory_scb) after_export;
    bit [memory_pkg::XLEN-1:0] model [bit [memory_pkg::VIR_ADDR_W-1:0]];
    bit known [bit [memory_pkg::VIR_ADDR_W-1:0]];

    function new(string name = "memory_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
    endfunction

    function void write(memory_txn txn);
        if (txn.resp_thrd !== txn.thrd)
            `uvm_error("MEMORY_SCB", "Response thread mismatch")
        if (!txn.we && known.exists(txn.addr) && known[txn.addr] &&
            txn.rdata !== model[txn.addr])
            `uvm_error("MEMORY_SCB",
                $sformatf("Read mismatch port=%0d addr=0x%h expected=0x%h actual=0x%h",
                          txn.port, txn.addr, model[txn.addr], txn.rdata))
        if (txn.we) begin
            model[txn.addr] = txn.wdata;
            known[txn.addr] = 1'b1;
        end
    endfunction
endclass: memory_scb

