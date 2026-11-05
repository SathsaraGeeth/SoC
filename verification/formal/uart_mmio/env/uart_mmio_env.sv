`default_nettype none
module uart_mmio_formal (
    input logic clk, input logic rst_n, input logic req_we,
    input logic [memory_pkg::THRD_W-1:0] req_thrd,
    input logic req_is_lr, input logic req_is_sc,
    input logic [core_pkg::VIR_ADDR_W-1:0] req_addr,
    input logic [core_pkg::XLEN/8-1:0] req_wstrb,
    input logic [core_pkg::XLEN-1:0] req_wdata,
    input logic req_valid, input logic [isa_pkg::PRIV_MODE_W-1:0] req_priv,
    input logic resp_ready, input logic rx
);
    logic req_ready, resp_sc_succ, resp_valid, tx;
    logic [memory_pkg::THRD_W-1:0] resp_thrd;
    logic [core_pkg::XLEN-1:0] resp_rdata;
    logic f_past_valid = 1'b0;

    uart_mmio #(.RX_DEPTH(2), .TX_DEPTH(2)) dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_req_we(req_we), .i_req_thrd(req_thrd),
        .i_req_is_lr(req_is_lr), .i_req_is_sc(req_is_sc), .i_req_addr(req_addr),
        .i_req_wstrb(req_wstrb), .i_req_wdata(req_wdata), .i_req_valid(req_valid),
        .i_req_priv(req_priv), .o_req_ready(req_ready), .o_resp_thrd(resp_thrd),
        .o_resp_sc_succ(resp_sc_succ), .o_resp_rdata(resp_rdata),
        .o_resp_valid(resp_valid), .i_resp_ready(resp_ready), .i_rx(rx), .o_tx(tx)
    );
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    `include "uart_mmio_assumptions.sv"
    `include "uart_mmio_reset.sv"
    `include "uart_mmio_protocol.sv"
    `include "uart_mmio_registers.sv"
    `include "uart_mmio_coverpoints.sv"
endmodule: uart_mmio_formal
`default_nettype wire

