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

class regfile_mon extends uvm_monitor;
    `uvm_component_utils(regfile_mon)

    virtual regfile_if vif;
    uvm_analysis_port #(regfile_txn) after_ap;

    function new(string name = "regfile_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual regfile_if)::get(this, "", "vif", vif))
            `uvm_fatal("REGFILE_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        regfile_txn txn;

        forever begin
            @(posedge vif.clk);
            #1ps;
            txn = regfile_txn::type_id::create("txn");
            txn.we        = vif.we;
            txn.rs1_addr  = vif.rs1_addr;
            txn.rs2_addr  = vif.rs2_addr;
            txn.rs3_addr  = vif.rs3_addr;
            txn.rthrd_id  = vif.rthrd_id;
            txn.rd_addr   = vif.rd_addr;
            txn.wthrd_id  = vif.wthrd_id;
            txn.rd_wdata  = vif.rd_wdata;
            txn.rs1_data  = vif.rs1_data;
            txn.rs2_data  = vif.rs2_data;
            txn.rs3_data  = vif.rs3_data;
            after_ap.write(txn);
        end
    endtask: run_phase
endclass: regfile_mon
