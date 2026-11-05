/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac20i_v2_env extends uvm_env;
    `uvm_component_utils(mac20i_v2_env)
    mac20i_v2_agent u_agent; mac20i_v2_scb u_scb; mac20i_v2_cov u_cov;
    function new(string name = "mac20i_v2_env", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); u_agent = mac20i_v2_agent::type_id::create("u_agent", this); u_scb = mac20i_v2_scb::type_id::create("u_scb", this); u_cov = mac20i_v2_cov::type_id::create("u_cov", this); endfunction
    function void connect_phase(uvm_phase phase); u_agent.mon.before_ap.connect(u_scb.before_export); u_agent.mon.after_ap.connect(u_scb.after_export); u_agent.mon.before_ap.connect(u_cov.analysis_export); endfunction
endclass: mac20i_v2_env
