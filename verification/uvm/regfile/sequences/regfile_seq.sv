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

class regfile_seq extends uvm_sequence #(regfile_txn);
    `uvm_object_utils(regfile_seq)

    function new(string name = "regfile_seq");
        super.new(name);
    endfunction

    virtual task body();
        regfile_txn txn;

        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            for (int r = 1; r < REG_COUNT; r++) begin
                txn = regfile_txn::type_id::create("init_txn");
                start_item(txn);
                txn.we        = 1'b1;
                txn.rs1_addr  = '0;
                txn.rs2_addr  = '0;
                txn.rs3_addr  = '0;
                txn.rthrd_id  = t;
                txn.rd_addr   = r;
                txn.wthrd_id  = t;
                txn.rd_wdata  = (64'(t) << 32) | 64'(r);
                finish_item(txn);
            end
        end

        repeat (2000) begin
            txn = regfile_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else
                `uvm_error("REGFILE_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask: body
endclass: regfile_seq

