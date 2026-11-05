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
import core_pkg::*;
`include "uvm_macros.svh"

class csr_mon extends uvm_monitor;
    `uvm_component_utils(csr_mon)

    virtual csr_if vif;
    uvm_analysis_port #(csr_txn) after_ap;

    function new(string name = "csr_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual csr_if)::get(this, "", "vif", vif))
            `uvm_fatal("CSR_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        csr_txn txn;

        forever begin
            @(posedge vif.clk);
            #1ps;
            txn = csr_txn::type_id::create("txn");
            txn.rst_n      = vif.rst_n;
            txn.kind       = vif.trap_we ? 1 : vif.mret_we ? 2 :
                             vif.sret_we ? 3 : vif.we ? 0 : 4;
            txn.rd_addr    = vif.rd_addr;
            txn.rs_addr    = vif.rs1_addr_vec[vif.wthrd_id];
            txn.thrd_id    = vif.wthrd_id;
            txn.wdata      = vif.rd_wdata;
            txn.irq_timer  = vif.irq_timer_vec;
            txn.trap_to_s  = vif.trap_to_s;
            txn.rdata      = vif.rs1_data_vec[vif.wthrd_id];
            txn.priv_mode  = vif.priv_mode_vec[vif.wthrd_id];
            txn.medeleg    = vif.medeleg_vec[vif.wthrd_id];
            txn.mideleg    = vif.mideleg_vec[vif.wthrd_id];
            txn.irq_pending = vif.irq_pending_vec[vif.wthrd_id];
            after_ap.write(txn);
        end
    endtask: run_phase
endclass: csr_mon

