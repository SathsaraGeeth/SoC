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

class sram_bank_drv extends uvm_driver #(sram_bank_txn);
    `uvm_component_utils(sram_bank_drv)

    virtual sram_bank_if vif;

    function new(string name = "sram_bank_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sram_bank_if)::get(this, "", "vif", vif))
            `uvm_fatal("SRAM_BANK_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        sram_bank_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.req_port      <= txn.port;
            vif.req_thrd      <= txn.thrd;
            vif.lr            <= txn.lr;
            vif.sc            <= txn.sc;
            vif.raddr         <= txn.addr;
            vif.waddr         <= txn.addr;
            vif.wstrb         <= txn.wstrb;
            vif.wdata         <= txn.wdata;
            vif.we            <= txn.we;
            vif.resp_expected <= 1'b1;
            vif.resp_ready    <= txn.stall_cycles == 0;
            vif.req_valid     <= 1'b1;
            while (!vif.req_ready)
                @(negedge vif.clk);
            @(negedge vif.clk);
            vif.req_valid <= 1'b0;
            vif.lr        <= 1'b0;
            vif.sc        <= 1'b0;
            vif.we        <= 1'b0;
            repeat (txn.stall_cycles)
                @(negedge vif.clk);
            vif.resp_ready <= 1'b1;
            do @(posedge vif.clk); while (!vif.resp_valid);
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: sram_bank_drv
