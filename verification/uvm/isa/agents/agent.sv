/* 
 * verification/uvm/isa/commit_agent.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. A passive agent - cpu cores are autonomous
 *    so dont need an driver in the agent
 */

`include "uvm_macros.svh"

import uvm_pkg::*;

class commit_agent extends uvm_agent;
    `uvm_component_utils(commit_agent)

    commit_monitor             mon;
    uvm_analysis_port #(txn)   ap;

    function new(string name = "commit_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = commit_monitor::type_id::create("mon", this);
        ap  = new("ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);
    endfunction
    
endclass: commit_agent
