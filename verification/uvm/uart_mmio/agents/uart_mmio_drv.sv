/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_drv extends uvm_driver #(uart_mmio_txn);
    `uvm_component_utils(uart_mmio_drv)
    virtual uart_mmio_if vif;

    function new(string name = "uart_mmio_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_mmio_if)::get(this, "", "vif", vif))
            `uvm_fatal("UART_MMIO_DRV", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        uart_mmio_txn txn;
        int unsigned wait_cycles;
        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            do @(negedge vif.clk); while (!vif.req_ready);
            vif.req_we     <= txn.we;
            vif.req_thrd   <= txn.thrd;
            vif.req_addr   <= 64'h0000_0010_0000_0000 + txn.offset;
            vif.req_wstrb  <= txn.wstrb;
            vif.req_wdata  <= txn.wdata;
            vif.req_priv   <= txn.priv;
            vif.req_valid  <= 1'b1;
            @(negedge vif.clk);
            vif.req_valid <= 1'b0;
            vif.resp_ready <= 1'b0;
            repeat (txn.backpressure) @(negedge vif.clk);
            vif.resp_ready <= 1'b1;
            wait_cycles = 0;
            while (!vif.resp_valid) begin
                @(negedge vif.clk);
                wait_cycles++;
                if (wait_cycles == 100)
                    `uvm_fatal("UART_MMIO_DRV",
                        $sformatf("Response timeout offset=0x%02h write=%0b data=0x%016h",
                                  txn.offset, txn.we, txn.wdata))
            end
            @(negedge vif.clk);
            vif.resp_ready <= 1'b0;
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: uart_mmio_drv
