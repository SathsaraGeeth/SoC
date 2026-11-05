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

class timer_mon extends uvm_monitor;
    `uvm_component_utils(timer_mon)

    virtual timer_if vif;
    uvm_analysis_port #(timer_txn) after_ap;

    function new(string name = "timer_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual timer_if)::get(this, "", "vif", vif))
            `uvm_fatal("TIMER_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        timer_txn txn;

        forever begin
            @(posedge vif.clk);
            txn = timer_txn::type_id::create("txn");
            txn.rst_n         = vif.rst_n;
            txn.req_valid     = vif.req_valid;
            txn.pre_req_ready = vif.req_ready;
            txn.we            = vif.req_we;
            txn.word          = vif.req_addr[3:2];
            txn.wstrb         = vif.req_wstrb;
            txn.wdata         = vif.req_wdata;
            txn.resp_ready    = vif.resp_ready;
            #1ps;
            txn.req_ready     = vif.req_ready;
            txn.resp_valid    = vif.resp_valid;
            txn.rdata         = vif.resp_rdata;
            txn.irq           = vif.irq_timer;
            after_ap.write(txn);
        end
    endtask: run_phase
endclass: timer_mon

