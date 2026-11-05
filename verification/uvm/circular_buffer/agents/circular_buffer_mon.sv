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

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class circular_buffer_mon extends uvm_monitor;
    `uvm_component_utils(circular_buffer_mon)

    virtual circular_buffer_if vif;
    uvm_analysis_port #(circular_buffer_txn) after_ap;

    function new(string name = "circular_buffer_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual circular_buffer_if)::get(this, "", "vif", vif))
            `uvm_fatal("CIRCULAR_BUFFER_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        circular_buffer_txn txn;

        forever begin
            @(posedge vif.clk);
            txn = circular_buffer_txn::type_id::create("txn");
            txn.rst_n      = vif.rst_n;
            txn.clr_n      = vif.clr_n;
            txn.enq_valid  = vif.enq_valid;
            txn.deq_valid  = vif.deq_valid;
            txn.data       = vif.enq_tail_data;
            txn.pre_enq_ready = vif.enq_ready;
            txn.pre_deq_ready = vif.deq_ready;
            txn.head_data  = vif.head_data;
            #1ps;
            txn.enq_ready  = vif.enq_ready;
            txn.deq_ready  = vif.deq_ready;
            txn.full       = vif.full;
            txn.empty      = vif.empty;
            txn.level      = vif.level;
            after_ap.write(txn);
        end
    endtask: run_phase
endclass: circular_buffer_mon
