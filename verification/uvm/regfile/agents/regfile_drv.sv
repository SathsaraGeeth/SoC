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

class regfile_drv extends uvm_driver #(regfile_txn);
    `uvm_component_utils(regfile_drv)

    virtual regfile_if vif;

    function new(string name = "regfile_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual regfile_if)::get(this, "", "vif", vif))
            `uvm_fatal("REGFILE_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        regfile_txn txn;

        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.we        <= txn.we;
            vif.rs1_addr  <= txn.rs1_addr;
            vif.rs2_addr  <= txn.rs2_addr;
            vif.rs3_addr  <= txn.rs3_addr;
            vif.rthrd_id  <= txn.rthrd_id;
            vif.rd_addr   <= txn.rd_addr;
            vif.wthrd_id  <= txn.wthrd_id;
            vif.rd_wdata  <= txn.rd_wdata;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: regfile_drv

