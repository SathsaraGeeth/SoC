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

class memory_mon extends uvm_monitor;
    `uvm_component_utils(memory_mon)

    virtual memory_if vif;
    uvm_analysis_port #(memory_txn) after_ap;

    function new(string name = "memory_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual memory_if)::get(this, "", "vif", vif))
            `uvm_fatal("MEMORY_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        memory_txn txn;
        int port;

        forever begin
            @(posedge vif.clk);
            for (port = 0; port < memory_pkg::NUM_RW_PORTS; port++) begin
                if (vif.rst_n && vif.req_valid[port] && vif.req_ready[port]) begin
                    txn = memory_txn::type_id::create("txn");
                    txn.we    = vif.req_we[port];
                    txn.port  = port;
                    txn.thrd  = vif.req_thrd[port];
                    txn.addr  = vif.req_addr[port];
                    txn.wstrb = vif.req_wstrb[port];
                    txn.wdata = vif.req_wdata[port];
                    do @(posedge vif.clk);
                    while (!(vif.resp_valid[port] && vif.resp_ready[port]));
                    txn.rdata       = vif.resp_rdata[port];
                    txn.resp_thrd   = vif.resp_thrd[port];
                    after_ap.write(txn);
                end
            end
        end
    endtask: run_phase
endclass: memory_mon

