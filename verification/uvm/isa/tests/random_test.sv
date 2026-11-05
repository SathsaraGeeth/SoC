`include "uvm_macros.svh"
import uvm_pkg::*;

class random_test extends uvm_test;
    `uvm_component_utils(random_test)

    env env;

    function new(string name = "random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        
        #500000ns;
        `uvm_info("ISA_RANDOM_TEST", "Random ISA run reached its time limit", UVM_LOW)
        
        phase.drop_objection(this);
    endtask
endclass: random_test
