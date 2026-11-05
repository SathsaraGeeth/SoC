/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_test extends uvm_test;
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_test)
    mac_fp8_fp8_fp8_61_v2_env u_env;function new(string name="mac_fp8_fp8_fp8_61_v2_test",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);u_env=mac_fp8_fp8_fp8_61_v2_env::type_id::create("u_env",this);endfunction
    task run_phase(uvm_phase phase);mac_fp8_fp8_fp8_61_v2_seq seq;phase.raise_objection(this);seq=mac_fp8_fp8_fp8_61_v2_seq::type_id::create("seq");seq.start(u_env.u_agent.seqr);repeat(4)@(posedge u_env.u_agent.drv.vif.clk);phase.drop_objection(this);endtask
endclass: mac_fp8_fp8_fp8_61_v2_test
