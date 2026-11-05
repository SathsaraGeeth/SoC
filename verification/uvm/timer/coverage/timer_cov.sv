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

class timer_cov extends uvm_subscriber #(timer_txn);
    `uvm_component_utils(timer_cov)

    bit       request;
    bit       is_write;
    bit [1:0] word;
    bit       irq;

    covergroup timer_cg;
        cp_request: coverpoint request;
        cp_write:   coverpoint is_write;
        cp_word:    coverpoint word;
        cp_irq:     coverpoint irq;
        cross cp_write, cp_word;
    endgroup

    function new(string name = "timer_cov", uvm_component parent = null);
        super.new(name, parent);
        timer_cg = new();
    endfunction

    function void write(timer_txn txn);
        request = txn.req_valid && txn.pre_req_ready;
        is_write = txn.we;
        word    = txn.word;
        irq     = txn.irq;
        timer_cg.sample();
    endfunction
endclass: timer_cov
