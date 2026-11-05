`default_nettype none
module mac20i_v2_formal (
    input logic clk, input logic rst_n, input logic en, input logic clr_n,
    input logic start, input logic last, input logic [7:0] a, input logic [7:0] b
);
    logic done; logic [7:0] d; logic f_past_valid = 1'b0;
    mac20i_v2 #(.WIDTH_AB(8), .WIDTH_CD(8), .M(4)) dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_en(en), .i_clr_n(clr_n),
        .i_start(start), .i_last(last), .i_a(a), .i_b(b), .o_done(done), .o_d(d)
    );
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    `include "mac20i_v2_assumptions.sv"
    `include "mac20i_v2_reset.sv"
    `include "mac20i_v2_pipeline.sv"
    `include "mac20i_v2_coverpoints.sv"
endmodule: mac20i_v2_formal
`default_nettype wire
