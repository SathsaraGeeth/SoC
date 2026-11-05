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

class circular_buffer_cov extends uvm_subscriber #(circular_buffer_txn);
    `uvm_component_utils(circular_buffer_cov)

    bit       enq;
    bit       deq;
    bit       clear;
    bit [3:0] level;

    covergroup fifo_cg;
        cp_enq:   coverpoint enq;
        cp_deq:   coverpoint deq;
        cp_clear: coverpoint clear;
        cp_level: coverpoint level {
            bins empty = {0};
            bins body  = {[1:7]};
            bins full  = {8};
        }
        cross cp_enq, cp_deq;
    endgroup

    function new(string name = "circular_buffer_cov", uvm_component parent = null);
        super.new(name, parent);
        fifo_cg = new();
    endfunction

    function void write(circular_buffer_txn txn);
        enq   = txn.enq_valid && txn.enq_ready;
        deq   = txn.deq_valid && txn.deq_ready;
        clear = !txn.clr_n;
        level = txn.level;
        fifo_cg.sample();
    endfunction
endclass: circular_buffer_cov

