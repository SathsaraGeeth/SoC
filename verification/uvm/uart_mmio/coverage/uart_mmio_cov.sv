/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_cov extends uvm_subscriber #(uart_mmio_txn);
    `uvm_component_utils(uart_mmio_cov)
    bit response, is_write;
    bit [5:0] offset;
    bit [1:0] priv;
    covergroup uart_mmio_cg;
        cp_response: coverpoint response;
        cp_write: coverpoint is_write;
        cp_offset: coverpoint offset;
        cp_priv: coverpoint priv;
        cross cp_write, cp_offset;
    endgroup
    function new(string name = "uart_mmio_cov", uvm_component parent = null);
        super.new(name, parent);
        uart_mmio_cg = new();
    endfunction
    function void write(uart_mmio_txn txn);
        response = txn.is_response;
        is_write = txn.we;
        offset   = txn.offset;
        priv     = txn.priv;
        uart_mmio_cg.sample();
    endfunction
endclass: uart_mmio_cov
