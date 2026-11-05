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

class memory_seq extends uvm_sequence #(memory_txn);
    `uvm_object_utils(memory_seq)

    function new(string name = "memory_seq");
        super.new(name);
    endfunction

    virtual task body();
        memory_txn txn;
        bit [memory_pkg::VIR_ADDR_W-1:0] addr;
        bit [memory_pkg::XLEN-1:0] data;
        int unsigned port;
        bit [memory_pkg::THRD_W-1:0] thrd;

        repeat (240) begin
            addr = 8 * $urandom_range(0, 127);
            data = {$urandom(), $urandom()};
            port = $urandom_range(0, memory_pkg::NUM_RW_PORTS-1);
            thrd = $urandom();

            txn = memory_txn::type_id::create("write_txn");
            start_item(txn);
            assert (txn.randomize() with {
                we == 1'b1;
                this.port == local::port;
                this.thrd == local::thrd;
                this.addr == local::addr;
                wdata == local::data;
            });
            finish_item(txn);

            txn = memory_txn::type_id::create("read_txn");
            start_item(txn);
            assert (txn.randomize() with {
                we == 1'b0;
                this.port == local::port;
                this.thrd == local::thrd;
                this.addr == local::addr;
            });
            finish_item(txn);
        end
    endtask: body
endclass: memory_seq

