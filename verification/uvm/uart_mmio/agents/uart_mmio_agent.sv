/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_agent extends uvm_agent;
    `uvm_component_utils(uart_mmio_agent)
    uart_mmio_seqr seqr;
    uart_mmio_drv drv;
    uart_mmio_mon mon;
    uvm_analysis_port #(uart_mmio_txn) after_ap;

    function new(string name = "uart_mmio_agent", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = uart_mmio_seqr::type_id::create("seqr", this);
        drv  = uart_mmio_drv ::type_id::create("drv", this);
        mon  = uart_mmio_mon ::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.after_ap.connect(after_ap);
    endfunction
endclass: uart_mmio_agent

