`default_nettype none

module timer_formal (
    input logic        clk,
    input logic        rst_n,
    input logic        req_valid,
    input logic [63:0] req_addr,
    input logic        req_we,
    input logic [7:0]  req_wstrb,
    input logic [63:0] req_wdata,
    input logic        resp_ready
);
    logic        req_ready;
    logic        resp_valid;
    logic [63:0] resp_rdata;
    logic        irq_timer;
    logic        f_past_valid = 1'b0;

    timer dut (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .req_valid_i  (req_valid),
        .req_addr_i   (req_addr),
        .req_we_i     (req_we),
        .req_wstrb_i  (req_wstrb),
        .req_wdata_i  (req_wdata),
        .req_ready_o  (req_ready),
        .resp_valid_o (resp_valid),
        .resp_ready_i (resp_ready),
        .resp_rdata_o (resp_rdata),
        .irq_timer_o  (irq_timer)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "timer_assumptions.sv"
    `include "timer_reset.sv"
    `include "timer_counter.sv"
    `include "timer_protocol.sv"
    `include "timer_coverpoints.sv"
endmodule: timer_formal

`default_nettype wire

