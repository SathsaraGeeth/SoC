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

class sram_bank_seq extends uvm_sequence #(sram_bank_txn);
    `uvm_object_utils(sram_bank_seq)

    function new(string name = "sram_bank_seq");
        super.new(name);
    endfunction

    virtual task body();
        sram_bank_txn txn;

        repeat (500) begin
            txn = sram_bank_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize() with {
                lr == 1'b0;
                sc == 1'b0;
                addr inside {[0:127]};
                we dist {1'b0 := 50, 1'b1 := 50};
            }) else `uvm_error("SRAM_BANK_SEQ", "Randomization failed")
            finish_item(txn);
        end

        txn = sram_bank_txn::type_id::create("lr_txn");
        start_item(txn);
        assert (txn.randomize() with {
            lr == 1'b1; sc == 1'b0; we == 1'b0;
            addr == 9; thrd == 1; wstrb == '1;
        });
        finish_item(txn);

        txn = sram_bank_txn::type_id::create("sc_txn");
        start_item(txn);
        assert (txn.randomize() with {
            lr == 1'b0; sc == 1'b1; we == 1'b1;
            addr == 9; thrd == 1; wstrb == '1;
            wdata == 64'h0123_4567_89ab_cdef;
        });
        finish_item(txn);
    endtask: body
endclass: sram_bank_seq

