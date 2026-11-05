/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_txn extends uvm_sequence_item;
    rand bit        we;
    rand bit [2:0]  thrd;
    rand bit [5:0]  offset;
    rand bit [7:0]  wstrb;
    rand bit [63:0] wdata;
    rand bit [1:0]  priv;
    rand int unsigned backpressure;
    bit             is_response;
    bit [63:0]      rdata;
    bit             sc_succ;

    constraint c_request {
        offset inside {6'h00, 6'h08, 6'h10, 6'h18, 6'h20, 6'h28, 6'h30, 6'h38};
        offset[2:0] == 3'b000;
        priv dist {2'b00 := 20, 2'b11 := 80};
        backpressure inside {[0:4]};
        if (!we) wstrb == '0;
        if (we) offset != 6'h00;
    }

    `uvm_object_utils_begin(uart_mmio_txn)
        `uvm_field_int(we, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_int(offset, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(priv, UVM_ALL_ON)
        `uvm_field_int(backpressure, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_mmio_txn");
        super.new(name);
    endfunction
endclass: uart_mmio_txn
