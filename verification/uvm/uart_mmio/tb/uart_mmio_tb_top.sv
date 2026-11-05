/* SPDX-License-Identifier: Apache-2.0 */
`include "uvm_macros.svh"
import uvm_pkg::*;

module uart_mmio_tb_top;
    uart_mmio_if vif();
    uart_mmio #(.RX_DEPTH(4), .TX_DEPTH(4)) dut (
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_req_we(vif.req_we),
        .i_req_thrd(vif.req_thrd), .i_req_is_lr(vif.req_is_lr),
        .i_req_is_sc(vif.req_is_sc), .i_req_addr(vif.req_addr),
        .i_req_wstrb(vif.req_wstrb), .i_req_wdata(vif.req_wdata),
        .i_req_valid(vif.req_valid), .i_req_priv(vif.req_priv),
        .o_req_ready(vif.req_ready), .o_resp_thrd(vif.resp_thrd),
        .o_resp_sc_succ(vif.resp_sc_succ), .o_resp_rdata(vif.resp_rdata),
        .o_resp_valid(vif.resp_valid), .i_resp_ready(vif.resp_ready),
        .i_rx(vif.rx), .o_tx(vif.tx)
    );

    initial begin
        uvm_config_db#(virtual uart_mmio_if)::set(null, "*", "vif", vif);
        run_test();
    end
    initial begin
        vif.clk = 1'b0; vif.rst_n = 1'b0; vif.req_we = 1'b0;
        vif.req_thrd = '0; vif.req_is_lr = 1'b0; vif.req_is_sc = 1'b0;
        vif.req_addr = '0; vif.req_wstrb = '0; vif.req_wdata = '0;
        vif.req_valid = 1'b0; vif.req_priv = 2'b11; vif.resp_ready = 1'b0;
        vif.rx = 1'b1;
        repeat (5) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("uart_mmio_tb.vcd");
        $dumpvars(0, uart_mmio_tb_top);
    end
    always #5ns vif.clk = ~vif.clk;
endmodule: uart_mmio_tb_top
