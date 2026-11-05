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

class circular_buffer_drv extends uvm_driver #(circular_buffer_txn);
    `uvm_component_utils(circular_buffer_drv)

    virtual circular_buffer_if vif;

    function new(string name = "circular_buffer_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual circular_buffer_if)::get(this, "", "vif", vif))
            `uvm_fatal("CIRCULAR_BUFFER_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        circular_buffer_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.clk);
            vif.enq_valid     <= txn.enq_valid;
            vif.deq_valid     <= txn.deq_valid;
            vif.enq_tail_data <= txn.data;
            vif.clr_n         <= !txn.do_clear;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: circular_buffer_drv

