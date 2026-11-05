/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_test extends uvm_test;
    `uvm_component_utils(fp_iter_test)

    fp_iter_env u_env;

    function new(string name = "fp_iter_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_env = fp_iter_env::type_id::create("u_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fp_iter_seq seq;

        phase.raise_objection(this);
        seq = fp_iter_seq::type_id::create("seq");
        seq.start(u_env.u_agent.seqr);
        repeat (4) @(posedge u_env.u_agent.drv.vif.clk);
        phase.drop_objection(this);
    endtask
endclass: fp_iter_test
