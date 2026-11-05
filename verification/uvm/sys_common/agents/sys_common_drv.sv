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
class sys_common_drv extends uvm_driver #(sys_common_txn);
    `uvm_component_utils(sys_common_drv)
    virtual sys_common_if vif;

    function new(string name = "sys_common_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sys_common_if)::get(this, "", "vif", vif))
            `uvm_fatal("SYS_COMMON_DRV", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        sys_common_txn txn;
        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.en     <= txn.en;
            vif.clr_n  <= txn.clr_n;
            vif.start  <= txn.start;
            vif.sel    <= txn.sel;
            vif.data0  <= txn.data0;
            vif.data1  <= txn.data1;
            vif.ptr    <= txn.ptr;
            vif.target <= txn.target;
            @(negedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass: sys_common_drv

