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

class memory_drv extends uvm_driver #(memory_txn);
    `uvm_component_utils(memory_drv)

    virtual memory_if vif;

    function new(string name = "memory_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual memory_if)::get(this, "", "vif", vif))
            `uvm_fatal("MEMORY_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        memory_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.req_we[txn.port]       <= txn.we;
            vif.req_thrd[txn.port]     <= txn.thrd;
            vif.req_addr[txn.port]     <= txn.addr;
            vif.req_wstrb[txn.port]    <= txn.wstrb;
            vif.req_wdata[txn.port]    <= txn.wdata;
            vif.req_priv[txn.port]     <= isa_pkg::PRIV_MODE_M;
            vif.req_valid[txn.port]    <= 1'b1;
            while (!vif.req_ready[txn.port])
                @(negedge vif.clk);
            @(negedge vif.clk);
            vif.req_valid[txn.port] <= 1'b0;
            do @(posedge vif.clk);
            while (!(vif.resp_valid[txn.port] && vif.resp_ready[txn.port]));
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: memory_drv

