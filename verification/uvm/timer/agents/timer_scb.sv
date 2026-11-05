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

class timer_scb extends uvm_scoreboard;
    `uvm_component_utils(timer_scb)

    uvm_analysis_export #(timer_txn) after_export;
    uvm_tlm_analysis_fifo #(timer_txn) after_fifo;
    bit [63:0] mtime;
    bit [63:0] mtimecmp = '1;

    function new(string name = "timer_scb", uvm_component parent = null);
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
        timer_txn txn;
        bit [63:0] old_mtime;
        bit [63:0] expected_rdata;

        forever begin
            after_fifo.get(txn);
            if (!txn.rst_n) begin
                mtime    = '0;
                mtimecmp = '1;
            end else begin
                old_mtime = mtime;
                mtime++;
                if (txn.req_valid && txn.pre_req_ready) begin
                    if (txn.we) begin
                        if (txn.word == 2)
                            mtimecmp[31:0] = apply_strobes(
                                mtimecmp[31:0], txn.wdata[31:0], txn.wstrb[3:0]);
                        if (txn.word == 3)
                            mtimecmp[63:32] = apply_strobes(
                                mtimecmp[63:32], txn.wdata[63:32], txn.wstrb[7:4]);
                    end else begin
                        unique case (txn.word)
                            0: expected_rdata = {32'b0, old_mtime[31:0]};
                            1: expected_rdata = {old_mtime[63:32], 32'b0};
                            2: expected_rdata = {32'b0, mtimecmp[31:0]};
                            3: expected_rdata = {mtimecmp[63:32], 32'b0};
                        endcase
                        if (!txn.resp_valid || txn.rdata !== expected_rdata)
                            `uvm_error("TIMER_SCB",
                                $sformatf("Read mismatch word=%0d expected=0x%016h actual=0x%016h",
                                          txn.word, expected_rdata, txn.rdata))
                    end
                end
            end

            if (txn.irq !== (mtime >= mtimecmp))
                `uvm_error("TIMER_SCB", "Interrupt threshold mismatch")
            if (txn.req_ready !== (!txn.resp_valid || txn.resp_ready))
                `uvm_error("TIMER_SCB", "Request-ready/response-backpressure mismatch")
        end
    endtask: run_phase

    function automatic bit [31:0] apply_strobes(
        bit [31:0] old_value,
        bit [31:0] new_value,
        bit [3:0] strobes
    );
        bit [31:0] result;

        result = old_value;
        for (int i = 0; i < 4; i++)
            if (strobes[i])
                result[i*8 +: 8] = new_value[i*8 +: 8];
        return result;
    endfunction
endclass: timer_scb

