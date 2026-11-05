/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_test extends uvm_test;
    `uvm_component_utils(uart_mmio_test)
    uart_mmio_env u_env;
    function new(string name = "uart_mmio_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_env = uart_mmio_env::type_id::create("u_env", this);
    endfunction
    task run_phase(uvm_phase phase);
        uart_mmio_seq seq;
        phase.raise_objection(this);
        seq = uart_mmio_seq::type_id::create("seq");
        seq.start(u_env.u_agent.seqr);
        repeat (8) @(posedge u_env.u_agent.drv.vif.clk);
        phase.drop_objection(this);
    endtask
endclass: uart_mmio_test

