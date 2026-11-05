`default_nettype none
module mac_fp8_formal (
    input logic clk, input logic rst_n, input logic en, input logic clr_n,
    input logic start, input logic last, input logic [7:0] a, input logic [7:0] b
);
    logic done; logic [7:0] d; logic f_past_valid = 1'b0;
    mac_fp8_fp8_fp8_61_v2 dut(.i_clk(clk),.i_rst_n(rst_n),.i_en(en),.i_clr_n(clr_n),.i_start(start),.i_last(last),.o_done(done),.i_a(a),.i_b(b),.o_d(d));
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    `include "mac_fp8_assumptions.sv"
    `include "mac_fp8_reset.sv"
    `include "mac_fp8_pipeline.sv"
    `include "mac_fp8_coverpoints.sv"
endmodule: mac_fp8_formal
`default_nettype wire
