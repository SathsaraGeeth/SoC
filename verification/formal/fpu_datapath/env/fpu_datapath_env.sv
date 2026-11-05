`default_nettype none

import isa_pkg::*;
import fpu_pkg::*;

module fpu_datapath_formal (
    input logic clk,
    input logic rst_n,
    input logic l0_in_valid,
    input fp_op_e l0_op,
    input opd_fmt_e l0_a_fmt,
    input opd_fmt_e l0_b_fmt,
    input opd_fmt_e l0_c_fmt,
    input fp_format_e l0_result_fmt,
    input logic [XLEN-1:0] l0_in_thrd,
    input logic [XLEN-1:0] l0_a,
    input logic [XLEN-1:0] l0_b,
    input logic [XLEN-1:0] l0_c,
    input logic l0_out_ready,
    input logic l1_in_valid,
    input fp_op_e l1_op,
    input opd_fmt_e l1_a_fmt,
    input opd_fmt_e l1_b_fmt,
    input opd_fmt_e l1_c_fmt,
    input fp_format_e l1_result_fmt,
    input logic [XLEN-1:0] l1_in_thrd,
    input logic [XLEN-1:0] l1_a,
    input logic [XLEN-1:0] l1_b,
    input logic [XLEN-1:0] l1_c,
    input logic l1_out_ready
);
    logic l0_in_ready;
    logic l0_out_valid;
    logic [XLEN-1:0] l0_out_thrd;
    logic [XLEN-1:0] l0_result;
    logic l1_in_ready;
    logic l1_out_valid;
    logic [XLEN-1:0] l1_out_thrd;
    logic [XLEN-1:0] l1_result;
    logic f_past_valid = 1'b0;

    fpu_datapath dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_l0_in_valid(l0_in_valid), .o_l0_in_ready(l0_in_ready),
        .i_l0_op(l0_op), .i_l0_a_fmt(l0_a_fmt), .i_l0_b_fmt(l0_b_fmt),
        .i_l0_c_fmt(l0_c_fmt), .i_l0_result_fmt(l0_result_fmt),
        .i_l0_thrd(l0_in_thrd), .i_l0_a(l0_a), .i_l0_b(l0_b), .i_l0_c(l0_c),
        .i_l0_out_ready(l0_out_ready), .o_l0_out_valid(l0_out_valid),
        .o_l0_thrd(l0_out_thrd), .o_l0_result(l0_result),
        .i_l1_in_valid(l1_in_valid), .o_l1_in_ready(l1_in_ready),
        .i_l1_op(l1_op), .i_l1_a_fmt(l1_a_fmt), .i_l1_b_fmt(l1_b_fmt),
        .i_l1_c_fmt(l1_c_fmt), .i_l1_result_fmt(l1_result_fmt),
        .i_l1_thrd(l1_in_thrd), .i_l1_a(l1_a), .i_l1_b(l1_b), .i_l1_c(l1_c),
        .i_l1_out_ready(l1_out_ready), .o_l1_out_valid(l1_out_valid),
        .o_l1_thrd(l1_out_thrd), .o_l1_result(l1_result)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "fpu_datapath_assumptions.sv"
    `include "fpu_datapath_reset.sv"
    `include "fpu_datapath_routing.sv"
    `include "fpu_datapath_coverpoints.sv"
endmodule: fpu_datapath_formal

`default_nettype wire
