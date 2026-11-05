/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_mmio_mon extends uvm_monitor;
    `uvm_component_utils(uart_mmio_mon)
    virtual uart_mmio_if vif;
    uvm_analysis_port #(uart_mmio_txn) after_ap;
    bit stalled;
    logic [63:0] stalled_data;
    logic [2:0]  stalled_thrd;

    function new(string name = "uart_mmio_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_mmio_if)::get(this, "", "vif", vif))
            `uvm_fatal("UART_MMIO_MON", "Virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        uart_mmio_txn txn;
        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) begin
                stalled = 1'b0;
            end else begin
                if (stalled && (!vif.resp_valid || vif.resp_rdata !== stalled_data ||
                                vif.resp_thrd !== stalled_thrd))
                    `uvm_error("UART_MMIO_MON",
                        $sformatf("Stalled response changed valid=%0b data=%016h/%016h thrd=%0h/%0h",
                                  vif.resp_valid, vif.resp_rdata, stalled_data,
                                  vif.resp_thrd, stalled_thrd))
                stalled      = vif.resp_valid && !vif.resp_ready;
                stalled_data = vif.resp_rdata;
                stalled_thrd = vif.resp_thrd;

                if (vif.req_valid && vif.req_ready) begin
                    txn = uart_mmio_txn::type_id::create("request");
                    txn.we     = vif.req_we;
                    txn.thrd   = vif.req_thrd;
                    txn.offset = vif.req_addr[5:0];
                    txn.wstrb  = vif.req_wstrb;
                    txn.wdata  = vif.req_wdata;
                    txn.priv   = vif.req_priv;
                    after_ap.write(txn);
                end
                if (vif.resp_valid && vif.resp_ready) begin
                    txn = uart_mmio_txn::type_id::create("response");
                    txn.is_response = 1'b1;
                    txn.thrd        = vif.resp_thrd;
                    txn.rdata       = vif.resp_rdata;
                    txn.sc_succ     = vif.resp_sc_succ;
                    after_ap.write(txn);
                end
            end
        end
    endtask: run_phase
endclass: uart_mmio_mon
