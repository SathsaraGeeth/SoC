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

class alu_drv extends uvm_driver #(alu_txn);
    `uvm_component_utils(alu_drv)

    virtual alu_if vif;

    function new(string name = "alu_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("ALU_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            drive_requests();
            drive_backpressure();
        join
    endtask: run_phase

    task drive_requests();
        alu_txn txn;
        issue_instr_t item;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            item = '0;
            item.thrd_id            = txn.thrd_id;
            item.rs1_data           = txn.a;
            item.rs2_data           = txn.b;
            item.instr.pc           = txn.pc;
            item.instr.imm          = txn.imm;
            item.instr.use_imm      = txn.use_imm;
            item.instr.use_pc       = txn.use_pc;
            item.instr.alu_word     = txn.word_op;
            item.instr.alu_op       = txn.op;
            item.instr.is_branch    = txn.control_kind == 1;
            item.instr.is_jump      = txn.control_kind == 2 || txn.control_kind == 3;
            item.instr.is_jalr      = txn.control_kind == 3;
            item.instr.funct3       = txn.funct3;

            @(negedge vif.clk);
            while (!vif.req_ready[txn.lane])
                @(negedge vif.clk);
            vif.issued_instr[txn.lane] <= item;
            vif.req_valid[txn.lane]    <= 1'b1;
            @(negedge vif.clk);
            vif.req_valid[txn.lane]    <= 1'b0;
            seq_item_port.item_done();
        end
    endtask: drive_requests

    task drive_backpressure();
        forever begin
            @(negedge vif.clk);
            vif.res_ready[0] <= $urandom_range(0, 99) < 80;
            vif.res_ready[1] <= $urandom_range(0, 99) < 80;
        end
    endtask: drive_backpressure
endclass: alu_drv

