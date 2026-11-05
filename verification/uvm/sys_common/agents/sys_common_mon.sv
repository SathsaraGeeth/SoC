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
class sys_common_mon extends uvm_monitor;
    `uvm_component_utils(sys_common_mon)
    virtual sys_common_if vif;
    uvm_analysis_port #(sys_common_txn) after_ap;

    function new(string name = "sys_common_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sys_common_if)::get(this, "", "vif", vif))
            `uvm_fatal("SYS_COMMON_MON", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        sys_common_txn txn;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(posedge vif.clk);
            #1ps;
            txn = sys_common_txn::type_id::create("txn");
            txn.en        = vif.en;
            txn.clr_n     = vif.clr_n;
            txn.start     = vif.start;
            txn.sel       = vif.sel;
            txn.data0     = vif.data0;
            txn.data1     = vif.data1;
            txn.ptr       = vif.ptr;
            txn.target    = vif.target;
            txn.reg_out   = vif.reg_out;
            txn.mux_out   = vif.mux_out;
            txn.pipe_out  = vif.pipe_out;
            txn.mul_out   = vif.mul_out;
            txn.add_out   = vif.add_out;
            txn.pipev_out = vif.pipev_out;
            txn.done      = vif.done;
            after_ap.write(txn);
        end
    endtask
endclass: sys_common_mon

