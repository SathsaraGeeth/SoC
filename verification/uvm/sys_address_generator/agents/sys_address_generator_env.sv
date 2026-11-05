/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_env extends uvm_env;
    `uvm_component_utils(sys_address_generator_env)
    sys_address_generator_agent u_agent; sys_address_generator_scb u_scb; sys_address_generator_cov u_cov;
    function new(string name = "sys_address_generator_env", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); u_agent = sys_address_generator_agent::type_id::create("u_agent", this);
        u_scb = sys_address_generator_scb::type_id::create("u_scb", this); u_cov = sys_address_generator_cov::type_id::create("u_cov", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        u_agent.mon.before_ap.connect(u_scb.before_export); u_agent.mon.after_ap.connect(u_scb.after_export); u_agent.mon.before_ap.connect(u_cov.analysis_export);
    endfunction
endclass: sys_address_generator_env
