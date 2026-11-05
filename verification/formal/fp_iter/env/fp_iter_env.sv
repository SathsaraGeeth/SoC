`default_nettype none

import isa_pkg::*;
import fpu_pkg::*;

module fp_iter_formal (
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
    input logic l1_out_ready,
    input logic p0_out_valid,
    input logic [XLEN-1:0] p0_out_thrd,
    input logic [XLEN-1:0] p0_result,
    input logic p1_out_valid,
    input logic [XLEN-1:0] p1_out_thrd,
    input logic [XLEN-1:0] p1_result
);
    logic l0_in_ready, l0_out_valid;
    logic [XLEN-1:0] l0_out_thrd, l0_result;
    logic l1_in_ready, l1_out_valid;
    logic [XLEN-1:0] l1_out_thrd, l1_result;
    logic iter_owns_p0, iter_owns_p1;
    logic p0_in_valid, p1_in_valid;
    fp_op_e p0_op, p1_op;
    opd_fmt_e p0_a_fmt, p0_b_fmt, p0_c_fmt;
    opd_fmt_e p1_a_fmt, p1_b_fmt, p1_c_fmt;
    fp_format_e p0_result_fmt, p1_result_fmt;
    logic [XLEN-1:0] p0_in_thrd, p0_a, p0_b, p0_c;
    logic [XLEN-1:0] p1_in_thrd, p1_a, p1_b, p1_c;
    logic f_past_valid = 1'b0;

    fp_iter dut (
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
        .o_l1_thrd(l1_out_thrd), .o_l1_result(l1_result),
        .o_is_iter_own_p0(iter_owns_p0), .o_is_iter_own_p1(iter_owns_p1),
        .o_p0_in_valid(p0_in_valid), .o_p0_op(p0_op),
        .o_p0_a_fmt(p0_a_fmt), .o_p0_b_fmt(p0_b_fmt), .o_p0_c_fmt(p0_c_fmt),
        .o_p0_result_fmt(p0_result_fmt), .o_p0_thrd(p0_in_thrd),
        .o_p0_a(p0_a), .o_p0_b(p0_b), .o_p0_c(p0_c),
        .i_p0_out_valid(p0_out_valid), .i_p0_thrd(p0_out_thrd),
        .i_p0_result(p0_result),
        .o_p1_in_valid(p1_in_valid), .o_p1_op(p1_op),
        .o_p1_a_fmt(p1_a_fmt), .o_p1_b_fmt(p1_b_fmt), .o_p1_c_fmt(p1_c_fmt),
        .o_p1_result_fmt(p1_result_fmt), .o_p1_thrd(p1_in_thrd),
        .o_p1_a(p1_a), .o_p1_b(p1_b), .o_p1_c(p1_c),
        .i_p1_out_valid(p1_out_valid), .i_p1_thrd(p1_out_thrd),
        .i_p1_result(p1_result)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "fp_iter_assumptions.sv"
    `include "fp_iter_reset.sv"
    `include "fp_iter_routing.sv"
    `include "fp_iter_special.sv"
    `include "fp_iter_coverpoints.sv"
endmodule: fp_iter_formal

`default_nettype wire
