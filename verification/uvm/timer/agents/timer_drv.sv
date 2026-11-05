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

class timer_drv extends uvm_driver #(timer_txn);
    `uvm_component_utils(timer_drv)

    virtual timer_if vif;

    function new(string name = "timer_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual timer_if)::get(this, "", "vif", vif))
            `uvm_fatal("TIMER_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        timer_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            repeat (txn.backpressure) begin
                @(negedge vif.clk);
                vif.resp_ready <= 1'b0;
            end
            @(negedge vif.clk);
            while (!vif.req_ready) begin
                vif.resp_ready <= 1'b1;
                @(negedge vif.clk);
            end
            vif.req_addr   <= {60'b0, txn.word, 2'b00};
            vif.req_we     <= txn.we;
            vif.req_wstrb  <= txn.wstrb;
            vif.req_wdata  <= txn.wdata;
            vif.req_valid  <= 1'b1;
            vif.resp_ready <= 1'b1;
            @(negedge vif.clk);
            vif.req_valid  <= 1'b0;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: timer_drv

