/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

`include "uvm_macros.svh"
import uvm_pkg::*;

module fp_iter_tb_top;
    fp_iter_if vif();

    fp_iter dut (
        .i_clk(vif.clk), .i_rst_n(vif.rst_n),
        .i_l0_in_valid(vif.l_in_valid[0]), .o_l0_in_ready(vif.l_in_ready[0]),
        .i_l0_op(vif.l_op[0]), .i_l0_a_fmt(vif.l_a_fmt[0]),
        .i_l0_b_fmt(vif.l_b_fmt[0]), .i_l0_c_fmt(vif.l_c_fmt[0]),
        .i_l0_result_fmt(vif.l_result_fmt[0]), .i_l0_thrd(vif.l_in_thrd[0]),
        .i_l0_a(vif.l_a[0]), .i_l0_b(vif.l_b[0]), .i_l0_c(vif.l_c[0]),
        .i_l0_out_ready(vif.l_out_ready[0]), .o_l0_out_valid(vif.l_out_valid[0]),
        .o_l0_thrd(vif.l_out_thrd[0]), .o_l0_result(vif.l_result[0]),
        .i_l1_in_valid(vif.l_in_valid[1]), .o_l1_in_ready(vif.l_in_ready[1]),
        .i_l1_op(vif.l_op[1]), .i_l1_a_fmt(vif.l_a_fmt[1]),
        .i_l1_b_fmt(vif.l_b_fmt[1]), .i_l1_c_fmt(vif.l_c_fmt[1]),
        .i_l1_result_fmt(vif.l_result_fmt[1]), .i_l1_thrd(vif.l_in_thrd[1]),
        .i_l1_a(vif.l_a[1]), .i_l1_b(vif.l_b[1]), .i_l1_c(vif.l_c[1]),
        .i_l1_out_ready(vif.l_out_ready[1]), .o_l1_out_valid(vif.l_out_valid[1]),
        .o_l1_thrd(vif.l_out_thrd[1]), .o_l1_result(vif.l_result[1]),
        .o_is_iter_own_p0(vif.iter_owns_pipe[0]),
        .o_is_iter_own_p1(vif.iter_owns_pipe[1]),
        .o_p0_in_valid(vif.p_in_valid[0]), .o_p0_op(vif.p_op[0]),
        .o_p0_a_fmt(vif.p_a_fmt[0]), .o_p0_b_fmt(vif.p_b_fmt[0]),
        .o_p0_c_fmt(vif.p_c_fmt[0]), .o_p0_result_fmt(vif.p_result_fmt[0]),
        .o_p0_thrd(vif.p_in_thrd[0]), .o_p0_a(vif.p_a[0]),
        .o_p0_b(vif.p_b[0]), .o_p0_c(vif.p_c[0]),
        .i_p0_out_valid(vif.p_out_valid[0]), .i_p0_thrd(vif.p_out_thrd[0]),
        .i_p0_result(vif.p_result[0]),
        .o_p1_in_valid(vif.p_in_valid[1]), .o_p1_op(vif.p_op[1]),
        .o_p1_a_fmt(vif.p_a_fmt[1]), .o_p1_b_fmt(vif.p_b_fmt[1]),
        .o_p1_c_fmt(vif.p_c_fmt[1]), .o_p1_result_fmt(vif.p_result_fmt[1]),
        .o_p1_thrd(vif.p_in_thrd[1]), .o_p1_a(vif.p_a[1]),
        .o_p1_b(vif.p_b[1]), .o_p1_c(vif.p_c[1]),
        .i_p1_out_valid(vif.p_out_valid[1]), .i_p1_thrd(vif.p_out_thrd[1]),
        .i_p1_result(vif.p_result[1])
    );

    initial begin
        uvm_config_db#(virtual fp_iter_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk          = 1'b0;
        vif.rst_n        = 1'b0;
        vif.l_in_valid   = '0;
        vif.l_out_ready  = '1;
        vif.p_out_valid  = '0;
        for (int lane = 0; lane < 2; lane++) begin
            vif.l_op[lane]         = fpu_pkg::ADD;
            vif.l_a_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.l_b_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.l_c_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.l_result_fmt[lane] = fpu_pkg::FMT_FP32;
            vif.l_in_thrd[lane]    = '0;
            vif.l_a[lane]          = '0;
            vif.l_b[lane]          = '0;
            vif.l_c[lane]          = '0;
            vif.p_out_thrd[lane]   = '0;
            vif.p_result[lane]     = '0;
        end
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("fp_iter_tb.vcd");
        $dumpvars(0, fp_iter_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;

    initial begin
        #100us;
        $fatal(1, "fp_iter UVM watchdog expired");
    end
endmodule: fp_iter_tb_top
