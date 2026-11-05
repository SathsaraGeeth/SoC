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

class sram_bank_mon extends uvm_monitor;
    `uvm_component_utils(sram_bank_mon)

    virtual sram_bank_if vif;
    uvm_analysis_port #(sram_bank_txn) after_ap;

    function new(string name = "sram_bank_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sram_bank_if)::get(this, "", "vif", vif))
            `uvm_fatal("SRAM_BANK_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        sram_bank_txn txn;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.req_valid && vif.req_ready) begin
                txn = sram_bank_txn::type_id::create("txn");
                txn.we        = vif.we;
                txn.lr        = vif.lr;
                txn.sc        = vif.sc;
                txn.addr      = vif.raddr;
                txn.wstrb     = vif.wstrb;
                txn.wdata     = vif.wdata;
                txn.port      = vif.req_port;
                txn.thrd      = vif.req_thrd;
                txn.sc_succ   = vif.sc_succ;
                do begin
                    @(posedge vif.clk);
                end while (!(vif.resp_valid && vif.resp_ready));
                txn.rdata     = vif.rdata;
                txn.resp_port = vif.resp_port;
                txn.resp_thrd = vif.resp_thrd;
                after_ap.write(txn);
            end
        end
    endtask: run_phase
endclass: sram_bank_mon
