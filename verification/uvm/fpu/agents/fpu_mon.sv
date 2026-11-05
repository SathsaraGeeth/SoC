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

class fpu_mon extends uvm_monitor;
    `uvm_component_utils(fpu_mon)

    virtual fpu_if vif;
    uvm_analysis_port #(fpu_txn) before_ap;
    uvm_analysis_port #(fpu_txn) after_ap;

    function new(string name = "fpu_mon", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap  = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif))
            `uvm_fatal("FPU_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        fpu_txn txn;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.req_valid && vif.req_ready) begin
                txn = fpu_txn::type_id::create("request_txn");
                txn.op      = vif.issued_instr.instr.fpu_op;
                txn.a       = vif.issued_instr.rs1_data[31:0];
                txn.b       = vif.issued_instr.rs2_data[31:0];
                txn.thrd_id = vif.issued_instr.thrd_id;
                before_ap.write(txn);
            end
            if (vif.rst_n && vif.res_valid && vif.res_ready) begin
                txn = fpu_txn::type_id::create("result_txn");
                txn.result  = vif.result;
                txn.thrd_id = vif.res_thrd_id;
                after_ap.write(txn);
            end
        end
    endtask: run_phase
endclass: fpu_mon

