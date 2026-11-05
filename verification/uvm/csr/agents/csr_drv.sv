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

class csr_drv extends uvm_driver #(csr_txn);
    `uvm_component_utils(csr_drv)

    virtual csr_if vif;

    function new(string name = "csr_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual csr_if)::get(this, "", "vif", vif))
            `uvm_fatal("CSR_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        csr_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.we            <= txn.kind == 0;
            vif.rd_addr       <= txn.rd_addr;
            vif.wthrd_id      <= txn.thrd_id;
            vif.rd_wdata      <= txn.wdata;
            vif.irq_timer_vec <= txn.irq_timer;
            vif.trap_we       <= txn.kind == 1;
            vif.trap_to_s     <= txn.trap_to_s;
            vif.trap_mepc     <= txn.wdata;
            vif.trap_mcause   <= txn.wdata ^ 64'h55aa;
            vif.trap_tval     <= txn.wdata ^ 64'haa55;
            vif.mret_we       <= txn.kind == 2;
            vif.sret_we       <= txn.kind == 3;
            for (int t = 0; t < NUM_HW_THRDS; t++)
                vif.rs1_addr_vec[t] <= t == txn.thrd_id ? txn.rs_addr : CSR_THREAD_ID;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: csr_drv

