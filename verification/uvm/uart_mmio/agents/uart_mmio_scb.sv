/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_scb extends uvm_scoreboard;
    `uvm_component_utils(uart_mmio_scb)
    uvm_analysis_export #(uart_mmio_txn) after_export;
    uvm_tlm_analysis_fifo #(uart_mmio_txn) after_fifo;
    bit [63:0] txctrl, rxctrl, ie;
    bit [63:0] divisor = 64'd1085;
    bit [63:0] expected_data[$];
    bit        compare_data[$];
    bit [2:0]  expected_thrd[$];

    function new(string name = "uart_mmio_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
        after_fifo   = new("after_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        after_export.connect(after_fifo.analysis_export);
    endfunction

    function automatic bit [63:0] merge(bit [63:0] old_value,
                                        bit [63:0] new_value,
                                        bit [7:0] mask);
        bit [63:0] value = old_value;
        for (int i = 0; i < 8; i++)
            if (mask[i]) value[i*8 +: 8] = new_value[i*8 +: 8];
        return value;
    endfunction

    task run_phase(uvm_phase phase);
        uart_mmio_txn txn;
        bit [63:0] value;
        bit check;
        forever begin
            after_fifo.get(txn);
            if (!txn.is_response) begin
                check = 1'b1;
                unique case (txn.offset)
                    6'h10: value = txctrl;
                    6'h18: value = rxctrl;
                    6'h20: value = ie;
                    6'h30: value = divisor;
                    6'h38: value = '0;
                    default: begin value = '0; check = 1'b0; end
                endcase
                expected_data.push_back(value);
                compare_data.push_back(check);
                expected_thrd.push_back(txn.thrd);
                if (txn.we && txn.priv != 2'b00) begin
                    unique case (txn.offset)
                        6'h10: txctrl = merge(txctrl, txn.wdata, txn.wstrb);
                        6'h18: rxctrl = merge(rxctrl, txn.wdata, txn.wstrb);
                        6'h20: ie = merge(ie, txn.wdata, txn.wstrb) & 64'h3;
                        6'h30: divisor = merge(divisor, txn.wdata, txn.wstrb);
                        default: begin end
                    endcase
                end
            end else begin
                if (expected_data.size() == 0) begin
                    `uvm_error("UART_MMIO_SCB", "Response without an accepted request")
                end else begin
                    value = expected_data.pop_front();
                    check = compare_data.pop_front();
                    if (txn.thrd !== expected_thrd.pop_front())
                        `uvm_error("UART_MMIO_SCB", "Response thread tag mismatch")
                    if (txn.sc_succ !== 1'b0)
                        `uvm_error("UART_MMIO_SCB", "UART incorrectly reported SC success")
                    if (check && txn.rdata !== value)
                        `uvm_error("UART_MMIO_SCB",
                            $sformatf("Readback mismatch expected=0x%016h actual=0x%016h",
                                      value, txn.rdata))
                end
            end
        end
    endtask: run_phase
endclass: uart_mmio_scb
