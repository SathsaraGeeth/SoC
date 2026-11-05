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

class sram_bank_scb extends uvm_scoreboard;
    `uvm_component_utils(sram_bank_scb)

    uvm_analysis_imp #(sram_bank_txn, sram_bank_scb) after_export;
    bit [XLEN-1:0] model [BANK_DEPTH-1:0];
    bit            known [BANK_DEPTH-1:0];
    bit            reservation_valid;
    bit [BANK_ADDR_W-1:0] reservation_addr;
    bit [THRD_W-1:0] reservation_thrd;
    bit [BANK_WORD_W/8-1:0] reservation_wstrb;

    function new(string name = "sram_bank_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
    endfunction

    function void write(sram_bank_txn txn);
        bit expected_sc;
        bit [XLEN-1:0] updated;

        expected_sc = reservation_valid &&
                      reservation_addr == txn.addr &&
                      reservation_thrd == txn.thrd &&
                      reservation_wstrb == txn.wstrb;
        if (txn.sc_succ !== (txn.sc && expected_sc))
            `uvm_error("SRAM_BANK_SCB", "Store-conditional result mismatch")
        if (txn.resp_port !== txn.port || txn.resp_thrd !== txn.thrd)
            `uvm_error("SRAM_BANK_SCB",
                $sformatf("Response metadata mismatch expected port=%0d thrd=%0d actual port=%0d thrd=%0d",
                          txn.port, txn.thrd, txn.resp_port, txn.resp_thrd))
        if (known[txn.addr] && txn.rdata !== model[txn.addr])
            `uvm_error("SRAM_BANK_SCB",
                $sformatf("Read mismatch addr=%0d expected=0x%016h actual=0x%016h",
                          txn.addr, model[txn.addr], txn.rdata))

        if (txn.we && (!txn.sc || expected_sc)) begin
            updated = known[txn.addr] ? model[txn.addr] : '0;
            for (int byte_idx = 0; byte_idx < BANK_WORD_W/8; byte_idx++)
                if (txn.wstrb[byte_idx])
                    updated[byte_idx*8 +: 8] = txn.wdata[byte_idx*8 +: 8];
            model[txn.addr] = updated;
            known[txn.addr] = txn.wstrb == '1 || known[txn.addr];
            if (reservation_valid && reservation_addr == txn.addr)
                reservation_valid = 1'b0;
        end
        if (txn.lr) begin
            reservation_valid = 1'b1;
            reservation_addr  = txn.addr;
            reservation_thrd  = txn.thrd;
            reservation_wstrb = txn.wstrb;
        end
        if (txn.sc && reservation_valid && reservation_thrd == txn.thrd)
            reservation_valid = 1'b0;
    endfunction
endclass: sram_bank_scb
