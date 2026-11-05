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

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class decoder_mon extends uvm_monitor;
    `uvm_component_utils(decoder_mon)

    virtual decoder_if vif;
    uvm_analysis_port #(decoder_txn) after_ap;

    function new(string name = "decoder_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual decoder_if)::get(this, "", "vif", vif))
            `uvm_fatal("DECODER_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        decoder_txn txn;

        forever begin
            @(posedge vif.sample_clk);
            #1ps;
            txn = decoder_txn::type_id::create("txn");
            txn.instr   = vif.instr;
            txn.decoded = vif.decoded;
            txn.case_id = classify(vif.instr);
            after_ap.write(txn);
        end
    endtask: run_phase

    function bit [3:0] classify(bit [31:0] instr);
        unique case (instr[6:0])
            7'b0110011: begin
                if (instr[14:12] == 3'b111)
                    return 2;
                return instr[30] ? 1 : 0;
            end
            7'b0010011: return 3;
            7'b0000011: return instr[14:12] == 3'b010 ? 4 : 5;
            7'b0100011: return 6;
            7'b1100011: return 7;
            7'b1101111: return 8;
            7'b1100111: return 9;
            7'b0110111: return 10;
            7'b0010111: return 11;
            7'b1110011: return 12;
            default:    return 13;
        endcase
    endfunction: classify
endclass: decoder_mon
