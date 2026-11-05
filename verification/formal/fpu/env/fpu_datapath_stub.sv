`default_nettype none

import isa_pkg::*;
import fpu_pkg::*;

module fpu_datapath (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_l0_in_valid,
    output logic o_l0_in_ready,
    input fp_op_e i_l0_op,
    input opd_fmt_e i_l0_a_fmt,
    input opd_fmt_e i_l0_b_fmt,
    input opd_fmt_e i_l0_c_fmt,
    input fp_format_e i_l0_result_fmt,
    input logic [XLEN-1:0] i_l0_thrd,
    input logic [XLEN-1:0] i_l0_a,
    input logic [XLEN-1:0] i_l0_b,
    input logic [XLEN-1:0] i_l0_c,
    input logic i_l0_out_ready,
    output logic o_l0_out_valid,
    output logic [XLEN-1:0] o_l0_thrd,
    output logic [XLEN-1:0] o_l0_result,
    input logic i_l1_in_valid,
    output logic o_l1_in_ready,
    input fp_op_e i_l1_op,
    input opd_fmt_e i_l1_a_fmt,
    input opd_fmt_e i_l1_b_fmt,
    input opd_fmt_e i_l1_c_fmt,
    input fp_format_e i_l1_result_fmt,
    input logic [XLEN-1:0] i_l1_thrd,
    input logic [XLEN-1:0] i_l1_a,
    input logic [XLEN-1:0] i_l1_b,
    input logic [XLEN-1:0] i_l1_c,
    input logic i_l1_out_ready,
    output logic o_l1_out_valid,
    output logic [XLEN-1:0] o_l1_thrd,
    output logic [XLEN-1:0] o_l1_result
);
    assign o_l0_in_ready  = 1'b1;
    assign o_l0_out_valid = 1'b0;
    assign o_l0_thrd      = '0;
    assign o_l0_result    = '0;
    assign o_l1_in_ready  = 1'b1;
    assign o_l1_out_valid = 1'b0;
    assign o_l1_thrd      = '0;
    assign o_l1_result    = '0;
endmodule: fpu_datapath

`default_nettype wire
