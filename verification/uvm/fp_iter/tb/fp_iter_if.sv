/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

interface fp_iter_if;
    import isa_pkg::*;
    import fpu_pkg::*;

    logic            clk;
    logic            rst_n;
    logic [1:0]      l_in_valid;
    logic [1:0]      l_in_ready;
    fp_op_e          l_op [2];
    opd_fmt_e        l_a_fmt [2];
    opd_fmt_e        l_b_fmt [2];
    opd_fmt_e        l_c_fmt [2];
    fp_format_e      l_result_fmt [2];
    logic [XLEN-1:0] l_in_thrd [2];
    logic [XLEN-1:0] l_a [2];
    logic [XLEN-1:0] l_b [2];
    logic [XLEN-1:0] l_c [2];
    logic [1:0]      l_out_ready;
    logic [1:0]      l_out_valid;
    logic [XLEN-1:0] l_out_thrd [2];
    logic [XLEN-1:0] l_result [2];

    logic [1:0]      iter_owns_pipe;
    logic [1:0]      p_in_valid;
    fp_op_e          p_op [2];
    opd_fmt_e        p_a_fmt [2];
    opd_fmt_e        p_b_fmt [2];
    opd_fmt_e        p_c_fmt [2];
    fp_format_e      p_result_fmt [2];
    logic [XLEN-1:0] p_in_thrd [2];
    logic [XLEN-1:0] p_a [2];
    logic [XLEN-1:0] p_b [2];
    logic [XLEN-1:0] p_c [2];
    logic [1:0]      p_out_valid;
    logic [XLEN-1:0] p_out_thrd [2];
    logic [XLEN-1:0] p_result [2];
endinterface: fp_iter_if
