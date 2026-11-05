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

class reset_sync_mon extends uvm_monitor;
    `uvm_component_utils(reset_sync_mon)

    virtual reset_sync_if vif;
    uvm_analysis_port #(reset_sync_txn) after_ap;
    int unsigned reset_id;

    function new(string name = "reset_sync_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual reset_sync_if)::get(this, "", "vif", vif))
            `uvm_fatal("RESET_SYNC_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_clock();
            monitor_async_assert();
        join
    endtask: run_phase

    task monitor_clock();
        reset_sync_txn txn;

        forever begin
            @(posedge vif.clk);
            #1ps;
            txn = reset_sync_txn::type_id::create("txn");
            txn.async_rst_n = vif.async_rst_n;
            txn.rst_n       = vif.rst_n;
            txn.reset_id    = reset_id;
            after_ap.write(txn);
        end
    endtask: monitor_clock

    task monitor_async_assert();
        forever begin
            @(negedge vif.async_rst_n);
            reset_id++;
            #1ps;
            if (vif.rst_n !== 1'b0)
                `uvm_error("RESET_SYNC_MON", "Reset output did not assert asynchronously")
        end
    endtask: monitor_async_assert
endclass: reset_sync_mon
