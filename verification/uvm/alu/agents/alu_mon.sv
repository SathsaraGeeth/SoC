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

class alu_mon extends uvm_monitor;
    `uvm_component_utils(alu_mon)

    virtual alu_if vif;
    uvm_analysis_port #(alu_txn) before_ap;
    uvm_analysis_port #(alu_txn) after_ap;

    function new(string name = "alu_mon", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap  = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("ALU_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        alu_txn txn;

        forever begin
            @(posedge vif.clk);
            for (int lane = 0; lane < 2; lane++) begin
                if (vif.rst_n && vif.req_valid[lane] && vif.req_ready[lane]) begin
                    txn = alu_txn::type_id::create("request_txn");
                    txn.lane         = lane;
                    txn.op           = vif.issued_instr[lane].instr.alu_op;
                    txn.a            = vif.issued_instr[lane].rs1_data;
                    txn.b            = vif.issued_instr[lane].rs2_data;
                    txn.pc           = vif.issued_instr[lane].instr.pc;
                    txn.imm          = vif.issued_instr[lane].instr.imm;
                    txn.use_imm      = vif.issued_instr[lane].instr.use_imm;
                    txn.use_pc       = vif.issued_instr[lane].instr.use_pc;
                    txn.word_op      = vif.issued_instr[lane].instr.alu_word;
                    txn.control_kind = vif.issued_instr[lane].instr.is_branch ? 1 :
                                       vif.issued_instr[lane].instr.is_jalr ? 3 :
                                       vif.issued_instr[lane].instr.is_jump ? 2 : 0;
                    txn.funct3       = vif.issued_instr[lane].instr.funct3;
                    txn.thrd_id      = vif.issued_instr[lane].thrd_id;
                    before_ap.write(txn);
                end
                if (vif.rst_n && vif.res_valid[lane] && vif.res_ready[lane]) begin
                    txn = alu_txn::type_id::create("result_txn");
                    txn.lane      = lane;
                    txn.result    = vif.result[lane];
                    txn.br_target = vif.br_target[lane];
                    txn.br_taken  = vif.br_taken[lane];
                    txn.thrd_id   = vif.res_thrd_id[lane];
                    after_ap.write(txn);
                end
            end
        end
    endtask: run_phase
endclass: alu_mon

