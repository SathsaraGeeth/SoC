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
import core_pkg::*;
`include "uvm_macros.svh"

class fpu_drv extends uvm_driver #(fpu_txn);
    `uvm_component_utils(fpu_drv)

    virtual fpu_if vif;

    function new(string name = "fpu_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif))
            `uvm_fatal("FPU_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            drive_requests();
            drive_backpressure();
        join
    endtask: run_phase

    task drive_requests();
        fpu_txn txn;
        issue_instr_t item;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            item = '0;
            item.thrd_id           = txn.thrd_id;
            item.rs1_data          = {32'b0, txn.a};
            item.rs2_data          = {32'b0, txn.b};
            item.instr.fpu_op      = txn.op;
            @(negedge vif.clk);
            while (!vif.req_ready)
                @(negedge vif.clk);
            vif.issued_instr <= item;
            vif.req_valid    <= 1'b1;
            @(negedge vif.clk);
            vif.req_valid    <= 1'b0;
            seq_item_port.item_done();
        end
    endtask: drive_requests

    task drive_backpressure();
        forever begin
            @(negedge vif.clk);
            vif.res_ready <= $urandom_range(0, 99) < 75;
        end
    endtask: drive_backpressure
endclass: fpu_drv

