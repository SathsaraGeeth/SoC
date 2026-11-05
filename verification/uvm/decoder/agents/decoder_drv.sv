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

class decoder_drv extends uvm_driver #(decoder_txn);
    `uvm_component_utils(decoder_drv)

    virtual decoder_if vif;

    function new(string name = "decoder_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual decoder_if)::get(this, "", "vif", vif))
            `uvm_fatal("DECODER_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        decoder_txn txn;

        forever begin
            seq_item_port.get_next_item(txn);
            @(negedge vif.sample_clk);
            vif.instr <= txn.instr;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: decoder_drv

