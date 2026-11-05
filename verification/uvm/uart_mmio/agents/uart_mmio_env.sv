/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_env extends uvm_env;
    `uvm_component_utils(uart_mmio_env)
    uart_mmio_agent u_agent;
    uart_mmio_scb u_scb;
    uart_mmio_cov u_cov;
    function new(string name = "uart_mmio_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_agent = uart_mmio_agent::type_id::create("u_agent", this);
        u_scb   = uart_mmio_scb  ::type_id::create("u_scb", this);
        u_cov   = uart_mmio_cov  ::type_id::create("u_cov", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        u_agent.after_ap.connect(u_scb.after_export);
        u_agent.after_ap.connect(u_cov.analysis_export);
    endfunction
endclass: uart_mmio_env

