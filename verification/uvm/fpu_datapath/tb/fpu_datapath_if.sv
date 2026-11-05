/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

interface fpu_datapath_if;
    import isa_pkg::*;
    import fpu_pkg::*;

    logic            clk;
    logic            rst_n;
    logic [1:0]      in_valid;
    logic [1:0]      in_ready;
    fp_op_e          op [2];
    opd_fmt_e        a_fmt [2];
    opd_fmt_e        b_fmt [2];
    opd_fmt_e        c_fmt [2];
    fp_format_e      result_fmt [2];
    logic [XLEN-1:0] in_thrd [2];
    logic [XLEN-1:0] a [2];
    logic [XLEN-1:0] b [2];
    logic [XLEN-1:0] c [2];
    logic [1:0]      out_ready;
    logic [1:0]      out_valid;
    logic [XLEN-1:0] out_thrd [2];
    logic [XLEN-1:0] result [2];
endinterface: fpu_datapath_if
