`default_nettype none
import sys_cnfg_pkg::*;
module mmacu_core_v2_formal (
    input logic clk,input logic rst_n,input logic start,input logic last,input logic end_tile,
    input logic [M*WIDTH_AB-1:0] a,input logic [M*WIDTH_AB-1:0] b,
    input logic a_valid,input logic b_valid,input logic d_ready
);
    logic a_ready,b_ready; logic [M*WIDTH_CD-1:0] d; logic d_valid;
    logic f_past_valid=1'b0;
    mmacu_core_v2 #(.MAC_STATIC_TYPE(MAC20I_STATIC)) dut(
        .i_clk(clk),.i_rst_n(rst_n),.i_dense(1'b0),.i_mac_type(MAC20I),
        .i_k2($clog2(K+1)'(1)),.i_start(start),.i_last(last),.i_end(end_tile),
        .i_a(a),.i_b(b),.i_a_valid(a_valid),.i_b_valid(b_valid),
        .o_a_ready(a_ready),.o_b_ready(b_ready),.o_d(d),.o_d_valid(d_valid),.i_d_ready(d_ready));
    always_ff @(posedge clk) f_past_valid<=1'b1;
    `include "mmacu_core_v2_assumptions.sv"
    `include "mmacu_core_v2_reset.sv"
    `include "mmacu_core_v2_protocol.sv"
    `include "mmacu_core_v2_coverpoints.sv"
endmodule: mmacu_core_v2_formal
`default_nettype wire

