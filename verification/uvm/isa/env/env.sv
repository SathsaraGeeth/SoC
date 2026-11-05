`include "uvm_macros.svh"
import uvm_pkg::*;

class env extends uvm_env;
    `uvm_component_utils(env)

    commit_agent core_agent;
    scoreboard   scb;
    coverage     cov;

    function new(string name = "env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        core_agent = commit_agent::type_id::create("core_agent", this);
        scb        = scoreboard::type_id::create("scb", this);
        cov        = coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        core_agent.ap.connect(scb.item_export);
        core_agent.ap.connect(cov.analysis_export);
    endfunction
    
endclass: env
