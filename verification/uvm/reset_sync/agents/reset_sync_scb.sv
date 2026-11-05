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

class reset_sync_scb extends uvm_scoreboard;
    `uvm_component_utils(reset_sync_scb)

    uvm_analysis_export #(reset_sync_txn) after_export;
    uvm_tlm_analysis_fifo #(reset_sync_txn) after_fifo;
    int unsigned release_age;
    int unsigned last_reset_id;

    function new(string name = "reset_sync_scb", uvm_component parent = null);
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
        reset_sync_txn txn;

        forever begin
            after_fifo.get(txn);
            if (txn.reset_id != last_reset_id) begin
                release_age  = 0;
                last_reset_id = txn.reset_id;
            end
            if (!txn.async_rst_n) begin
                release_age = 0;
                if (txn.rst_n !== 1'b0)
                    `uvm_error("RESET_SYNC_SCB", "Output reset is high while asynchronous reset is asserted")
            end else begin
                release_age++;
                if (release_age < 2 && txn.rst_n !== 1'b0)
                    `uvm_error("RESET_SYNC_SCB",
                        $sformatf("Reset released too early at age %0d", release_age))
                if (release_age >= 3 && txn.rst_n !== 1'b1)
                    `uvm_error("RESET_SYNC_SCB",
                        $sformatf("Reset did not release by age %0d", release_age))
            end
        end
    endtask: run_phase
endclass: reset_sync_scb
