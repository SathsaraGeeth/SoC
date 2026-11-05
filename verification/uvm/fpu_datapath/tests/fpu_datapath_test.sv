/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_test extends uvm_test;
    `uvm_component_utils(fpu_datapath_test)

    fpu_datapath_env u_env;

    function new(string name = "fpu_datapath_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_env = fpu_datapath_env::type_id::create("u_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fpu_datapath_seq seq;

        phase.raise_objection(this);
        seq = fpu_datapath_seq::type_id::create("seq");
        seq.start(u_env.u_agent.seqr);
        repeat (16) @(posedge u_env.u_agent.drv.vif.clk);
        phase.drop_objection(this);
    endtask
endclass: fpu_datapath_test
