/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_seqr extends uvm_sequencer #(uart_mmio_txn);
    `uvm_component_utils(uart_mmio_seqr)
    function new(string name = "uart_mmio_seqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass: uart_mmio_seqr

