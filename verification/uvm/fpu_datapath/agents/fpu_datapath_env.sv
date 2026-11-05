/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_env extends uvm_env;
    `uvm_component_utils(fpu_datapath_env)

    fpu_datapath_agent u_agent;
    fpu_datapath_scb   u_scb;
    fpu_datapath_cov   u_cov;

    function new(string name = "fpu_datapath_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_agent = fpu_datapath_agent::type_id::create("u_agent", this);
        u_scb   = fpu_datapath_scb::type_id::create("u_scb", this);
        u_cov   = fpu_datapath_cov::type_id::create("u_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        u_agent.mon.before_ap.connect(u_scb.before_export);
        u_agent.mon.after_ap.connect(u_scb.after_export);
        u_agent.mon.before_ap.connect(u_cov.analysis_export);
    endfunction
endclass: fpu_datapath_env
