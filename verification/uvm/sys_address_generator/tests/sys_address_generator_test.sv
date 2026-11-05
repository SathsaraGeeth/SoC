/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_test extends uvm_test;
    `uvm_component_utils(sys_address_generator_test)
    sys_address_generator_env u_env;
    function new(string name = "sys_address_generator_test", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); u_env = sys_address_generator_env::type_id::create("u_env", this); endfunction
    task run_phase(uvm_phase phase);
        sys_address_generator_seq seq; phase.raise_objection(this); seq = sys_address_generator_seq::type_id::create("seq");
        seq.start(u_env.u_agent.seqr); repeat (4) @(posedge u_env.u_agent.drv.vif.clk); phase.drop_objection(this);
    endtask
endclass: sys_address_generator_test
