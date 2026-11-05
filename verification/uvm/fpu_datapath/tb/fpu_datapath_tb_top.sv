/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

`include "uvm_macros.svh"
import uvm_pkg::*;

module fpu_datapath_tb_top;
    fpu_datapath_if vif();

    fpu_datapath dut (
        .i_clk(vif.clk), .i_rst_n(vif.rst_n),
        .i_l0_in_valid(vif.in_valid[0]), .o_l0_in_ready(vif.in_ready[0]),
        .i_l0_op(vif.op[0]), .i_l0_a_fmt(vif.a_fmt[0]),
        .i_l0_b_fmt(vif.b_fmt[0]), .i_l0_c_fmt(vif.c_fmt[0]),
        .i_l0_result_fmt(vif.result_fmt[0]), .i_l0_thrd(vif.in_thrd[0]),
        .i_l0_a(vif.a[0]), .i_l0_b(vif.b[0]), .i_l0_c(vif.c[0]),
        .i_l0_out_ready(vif.out_ready[0]), .o_l0_out_valid(vif.out_valid[0]),
        .o_l0_thrd(vif.out_thrd[0]), .o_l0_result(vif.result[0]),
        .i_l1_in_valid(vif.in_valid[1]), .o_l1_in_ready(vif.in_ready[1]),
        .i_l1_op(vif.op[1]), .i_l1_a_fmt(vif.a_fmt[1]),
        .i_l1_b_fmt(vif.b_fmt[1]), .i_l1_c_fmt(vif.c_fmt[1]),
        .i_l1_result_fmt(vif.result_fmt[1]), .i_l1_thrd(vif.in_thrd[1]),
        .i_l1_a(vif.a[1]), .i_l1_b(vif.b[1]), .i_l1_c(vif.c[1]),
        .i_l1_out_ready(vif.out_ready[1]), .o_l1_out_valid(vif.out_valid[1]),
        .o_l1_thrd(vif.out_thrd[1]), .o_l1_result(vif.result[1])
    );

    initial begin
        uvm_config_db#(virtual fpu_datapath_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk       = 1'b0;
        vif.rst_n     = 1'b0;
        vif.in_valid  = '0;
        vif.out_ready = '1;
        for (int lane = 0; lane < 2; lane++) begin
            vif.op[lane]         = fpu_pkg::ADD;
            vif.a_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.b_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.c_fmt[lane]      = fpu_pkg::OP_FMT_FP32;
            vif.result_fmt[lane] = fpu_pkg::FMT_FP32;
            vif.in_thrd[lane]    = '0;
            vif.a[lane]          = '0;
            vif.b[lane]          = '0;
            vif.c[lane]          = '0;
        end
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("fpu_datapath_tb.vcd");
        $dumpvars(0, fpu_datapath_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: fpu_datapath_tb_top
