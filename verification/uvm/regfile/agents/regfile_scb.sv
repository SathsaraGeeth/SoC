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

class regfile_scb extends uvm_scoreboard;
    `uvm_component_utils(regfile_scb)

    uvm_analysis_export #(regfile_txn) after_export;
    uvm_tlm_analysis_fifo #(regfile_txn) after_fifo;
    bit [XLEN-1:0] model [NUM_HW_THRDS][REG_COUNT];
    bit            known [NUM_HW_THRDS][REG_COUNT];

    function new(string name = "regfile_scb", uvm_component parent = null);
        super.new(name, parent);
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            model[t][0] = '0;
            known[t][0] = 1'b1;
        end
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
        regfile_txn txn;

        forever begin
            after_fifo.get(txn);
            check_port("rs1", txn.rthrd_id, txn.rs1_addr, txn.rs1_data);
            check_port("rs2", txn.rthrd_id, txn.rs2_addr, txn.rs2_data);
            check_port("rs3", txn.rthrd_id, txn.rs3_addr, txn.rs3_data);
            if (txn.we && txn.rd_addr != '0) begin
                model[txn.wthrd_id][txn.rd_addr] = txn.rd_wdata;
                known[txn.wthrd_id][txn.rd_addr] = 1'b1;
            end
        end
    endtask: run_phase

    function void check_port(
        string name,
        int unsigned thrd,
        int unsigned addr,
        bit [XLEN-1:0] actual
    );
        if (known[thrd][addr] && actual !== model[thrd][addr])
            `uvm_error("REGFILE_SCB",
                $sformatf("%s mismatch thrd=%0d reg=%0d expected=0x%016h actual=0x%016h",
                          name, thrd, addr, model[thrd][addr], actual))
    endfunction
endclass: regfile_scb

