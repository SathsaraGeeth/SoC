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

class sram_bank_test extends uvm_test;
    `uvm_component_utils(sram_bank_test)

    sram_bank_env u_env;

    function new(string name = "sram_bank_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_env = sram_bank_env::type_id::create("u_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        sram_bank_seq seq;

        phase.raise_objection(this);
        seq = sram_bank_seq::type_id::create("seq");
        seq.start(u_env.u_agent.u_seqr);
        repeat (5) @(posedge u_env.u_agent.u_drv.vif.clk);
        phase.drop_objection(this);
    endtask
endclass: sram_bank_test

