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

class reset_sync_drv extends uvm_driver #(reset_sync_txn);
    `uvm_component_utils(reset_sync_drv)

    virtual reset_sync_if vif;

    function new(string name = "reset_sync_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual reset_sync_if)::get(this, "", "vif", vif))
            `uvm_fatal("RESET_SYNC_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        reset_sync_txn txn;

        vif.async_rst_n <= 1'b0;
        repeat (3) @(posedge vif.clk);
        vif.async_rst_n <= 1'b1;

        forever begin
            seq_item_port.get_next_item(txn);
            repeat (txn.high_cycles) @(posedge vif.clk);
            #(txn.phase_ps * 1ps);
            vif.async_rst_n <= 1'b0;
            repeat (txn.low_cycles) @(posedge vif.clk);
            vif.async_rst_n <= 1'b1;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: reset_sync_drv
