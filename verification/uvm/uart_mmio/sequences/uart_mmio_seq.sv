/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_seq extends uvm_sequence #(uart_mmio_txn);
    `uvm_object_utils(uart_mmio_seq)

    function new(string name = "uart_mmio_seq");
        super.new(name);
    endfunction

    task send(bit we, bit [5:0] offset, bit [63:0] data,
              bit [7:0] strb, bit [1:0] priv, int unsigned delay = 0);
        uart_mmio_txn txn;
        txn = uart_mmio_txn::type_id::create("txn");
        start_item(txn);
        txn.we           = we;
        txn.offset       = offset;
        txn.wdata        = data;
        txn.wstrb        = strb;
        txn.priv         = priv;
        txn.thrd         = $urandom_range(0, 63);
        txn.backpressure = delay;
        finish_item(txn);
    endtask: send

    virtual task body();
        uart_mmio_txn txn;

        send(0, 6'h10, '0, '0, 2'b11);
        send(0, 6'h18, '0, '0, 2'b11);
        send(0, 6'h20, '0, '0, 2'b11);
        send(0, 6'h30, '0, '0, 2'b11);
        send(1, 6'h10, 64'h0000_0000_0000_0005, 8'h01, 2'b11, 3);
        send(0, 6'h10, '0, '0, 2'b11);
        send(1, 6'h20, 64'hffff_ffff_ffff_ffff, 8'hff, 2'b11);
        send(0, 6'h20, '0, '0, 2'b11);
        send(1, 6'h30, 64'd16, 8'hff, 2'b11);
        send(0, 6'h30, '0, '0, 2'b11);
        send(1, 6'h18, 64'h55aa_0000_0000_0001, 8'h81, 2'b00);
        send(0, 6'h18, '0, '0, 2'b11);
        send(0, 6'h38, '0, '0, 2'b11);
        send(1, 6'h00, 64'h0000_0000_0000_00a5, 8'h01, 2'b11);

        repeat (250) begin
            txn = uart_mmio_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else
                `uvm_error("UART_MMIO_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask: body
endclass: uart_mmio_seq

