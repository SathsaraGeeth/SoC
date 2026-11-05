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

class circular_buffer_scb extends uvm_scoreboard;
    `uvm_component_utils(circular_buffer_scb)

    uvm_analysis_export #(circular_buffer_txn) after_export;
    uvm_tlm_analysis_fifo #(circular_buffer_txn) after_fifo;
    bit [7:0] model[$];

    function new(string name = "circular_buffer_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
        after_fifo   = new("after_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        after_export.connect(after_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        circular_buffer_txn txn;
        bit [7:0] expected;

        forever begin
            after_fifo.get(txn);
            if (!txn.rst_n || !txn.clr_n) begin
                model.delete();
            end else begin
                if (txn.deq_valid && txn.pre_deq_ready) begin
                    if (model.size() == 0) begin
                        `uvm_error("CIRCULAR_BUFFER_SCB", "DUT accepted a dequeue while empty")
                    end else begin
                        expected = model.pop_front();
                        if (txn.head_data !== expected)
                            `uvm_error("CIRCULAR_BUFFER_SCB",
                                $sformatf("Ordering mismatch expected=0x%02h actual=0x%02h",
                                          expected, txn.head_data))
                    end
                end
                if (txn.enq_valid && txn.pre_enq_ready)
                    model.push_back(txn.data);
            end

            if (txn.level !== model.size())
                `uvm_error("CIRCULAR_BUFFER_SCB",
                    $sformatf("Level mismatch expected=%0d actual=%0d",
                              model.size(), txn.level))
            if (txn.empty !== (model.size() == 0))
                `uvm_error("CIRCULAR_BUFFER_SCB", "Empty flag mismatch")
            if (txn.full !== (model.size() == 8))
                `uvm_error("CIRCULAR_BUFFER_SCB", "Full flag mismatch")
            if (txn.enq_ready !== !txn.full)
                `uvm_error("CIRCULAR_BUFFER_SCB", "Enqueue-ready mismatch")
            if (txn.deq_ready !== !txn.empty)
                `uvm_error("CIRCULAR_BUFFER_SCB", "Dequeue-ready mismatch")
        end
    endtask: run_phase
endclass: circular_buffer_scb
