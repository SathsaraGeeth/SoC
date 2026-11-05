`default_nettype none

module reset_sync_formal (
    input logic clk,
    input logic async_rst_n
);
    localparam int unsigned STAGES = 3;

    logic rst_n;
    logic f_past_valid = 1'b0;

    reset_sync #(
        .STAGES (STAGES)
    ) dut (
        .i_clk         (clk),
        .i_async_rst_n (async_rst_n),
        .o_rst_n       (rst_n)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "reset_sync_assumptions.sv"
    `include "reset_sync_reset.sv"
    `include "reset_sync_protocol.sv"
    `include "reset_sync_coverpoints.sv"
endmodule: reset_sync_formal

`default_nettype wire
