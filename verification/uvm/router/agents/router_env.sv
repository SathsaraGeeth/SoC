/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_env extends uvm_env;
    `uvm_component_utils(router_env)

    router_agent u_agent;
    router_scb u_scb;
    router_cov u_cov;

    function new(string name = "router_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_agent = router_agent::type_id::create("u_agent", this);
        u_scb = router_scb::type_id::create("u_scb", this);
        u_cov = router_cov::type_id::create("u_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        u_agent.before_ap.connect(u_scb.before_export);
        u_agent.before_ap.connect(u_cov.analysis_export);
        u_agent.after_ap.connect(u_scb.after_export);
    endfunction
endclass: router_env
