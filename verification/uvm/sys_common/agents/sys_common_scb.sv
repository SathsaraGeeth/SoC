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
class sys_common_scb extends uvm_scoreboard;
    `uvm_component_utils(sys_common_scb)
    uvm_analysis_imp #(sys_common_txn, sys_common_scb) after_export;

    bit [7:0] reg_model;
    bit [7:0] pipe_model [2];
    bit [7:0] pipev_model [5];
    bit [2:0] ptr_model;
    bit [2:0] sel_ptr_model;
    bit [15:0] mul_model;
    bit [15:0] add_model;
    bit [7:0] count_model;

    function new(string name = "sys_common_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
    endfunction

    function void write(sys_common_txn txn);
        bit [7:0] old_pipe [2];
        bit [7:0] old_pipev [5];
        bit [2:0] old_ptr;
        bit signed [7:0] signed0;
        bit signed [7:0] signed1;
        bit signed [15:0] extended0;
        bit signed [15:0] extended1;

        old_pipe = pipe_model;
        old_pipev = pipev_model;
        old_ptr = ptr_model;
        signed0 = txn.data0;
        signed1 = txn.data1;
        extended0 = signed0;
        extended1 = signed1;

        if (!txn.clr_n) begin
            reg_model = '0;
            pipe_model = '{default:'0};
            pipev_model = '{default:'0};
            mul_model = '0;
            add_model = '0;
        end else if (txn.en) begin
            reg_model = txn.data0;
            pipe_model[0] = txn.data0;
            pipe_model[1] = old_pipe[0];
            mul_model = signed0 * signed1;
            add_model = extended0 + extended1;
        end
        pipev_model[0] = txn.data0;
        if (!txn.clr_n) begin
            for (int stage = 1; stage <= 4; stage++)
                pipev_model[stage] = '0;
        end else if (txn.en) begin
            pipev_model[1] = txn.data0;
            pipev_model[2] = old_pipev[1];
            pipev_model[3] = old_pipev[2];
            pipev_model[4] = old_pipev[3];
        end
        if (txn.en) begin
            sel_ptr_model = ptr_model;
            ptr_model = txn.ptr;
        end

        if (txn.start)
            count_model = '0;
        else if (txn.en && count_model != txn.target)
            count_model++;

        if (txn.reg_out !== reg_model)
            `uvm_error("SYS_COMMON_SCB", "Register mismatch")
        if (txn.mux_out !== (txn.sel ? txn.data1 : txn.data0))
            `uvm_error("SYS_COMMON_SCB", "Mux mismatch")
        if (txn.pipe_out !== pipe_model[1])
            `uvm_error("SYS_COMMON_SCB", "Fixed-delay pipe mismatch")
        if (txn.mul_out !== mul_model)
            `uvm_error("SYS_COMMON_SCB", "Multiplier mismatch")
        if (txn.add_out !== add_model)
            `uvm_error("SYS_COMMON_SCB", "Adder mismatch")
        if (txn.pipev_out !== pipev_model[sel_ptr_model])
            `uvm_error("SYS_COMMON_SCB",
                $sformatf("Variable-delay pipe mismatch ptr=%0d expected=0x%h actual=0x%h",
                          sel_ptr_model, pipev_model[sel_ptr_model], txn.pipev_out))
        if (txn.done !== (count_model == txn.target))
            `uvm_error("SYS_COMMON_SCB", "Counter mismatch")
    endfunction
endclass: sys_common_scb
