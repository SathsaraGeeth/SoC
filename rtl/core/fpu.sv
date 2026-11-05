/*
 * fpu.sv
 * 
 * Copyright (C) 2026 Sathsara Geeth
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 */

`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;
import isa_pkg::*;
import fpu_pkg::*;

module fpu (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    issue_instr_t                           i_issued_instr,
    output logic                            o_req_ready,
    input  logic                            i_req_valid,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_res_thrd_id,
    output logic                            o_res_valid,
    input  logic                            i_res_ready,    
    output logic [VIR_ADDR_W-1:0]           o_result
);
    logic                            r_busy;
    logic                            r_result_valid;
    logic [$clog2(NUM_HW_THRDS)-1:0] r_result_thrd;
    logic [XLEN-1:0]                 r_result;

    logic                            w_accept;
    logic                            w_is_simple;
    logic [XLEN-1:0]                 w_simple_result;
    fp_op_e                          w_dp_op;
    opd_fmt_e                        w_a_fmt;
    logic                            w_use_lane1;
    logic                            w_l0_ready;
    logic                            w_l0_valid;
    logic [XLEN-1:0]                 w_l0_thrd;
    logic [XLEN-1:0]                 w_l0_result;
    logic                            w_l1_ready;
    logic                            w_l1_valid;
    logic [XLEN-1:0]                 w_l1_thrd;
    logic [XLEN-1:0]                 w_l1_result;
    logic                            w_dp_result_valid;
    logic [XLEN-1:0]                 w_dp_result;
    logic [XLEN-1:0]                 w_dp_c;

    function automatic logic fp32_is_nan(input logic [31:0] value);
        return value[30:23] == 8'hff && value[22:0] != '0;
    endfunction

    function automatic logic fp32_eq(input logic [31:0] a, input logic [31:0] b);
        if (fp32_is_nan(a) || fp32_is_nan(b))
            return 1'b0;
        return (a[30:0] == '0 && b[30:0] == '0) || a == b;
    endfunction

    function automatic logic fp32_lt(input logic [31:0] a, input logic [31:0] b);
        if (fp32_is_nan(a) || fp32_is_nan(b) || fp32_eq(a, b))
            return 1'b0;
        if (a[31] != b[31])
            return a[31];
        return a[31] ? (a[30:0] > b[30:0]) : (a[30:0] < b[30:0]);
    endfunction

    function automatic logic [9:0] fp32_class(input logic [31:0] value);
        logic sign;
        logic [7:0] exp;
        logic [22:0] frac;
        logic [9:0] result;
        sign = value[31];
        exp = value[30:23];
        frac = value[22:0];
        result = '0;
        if (exp == 8'hff && frac == '0) result[sign ? 0 : 7] = 1'b1;
        else if (exp == 8'hff)          result[frac[22] ? 9 : 8] = 1'b1;
        else if (exp == '0 && frac == '0) result[sign ? 3 : 4] = 1'b1;
        else if (exp == '0)             result[sign ? 2 : 5] = 1'b1;
        else                            result[sign ? 1 : 6] = 1'b1;
        return result;
    endfunction

    always_comb begin
        w_is_simple = 1'b0;
        w_simple_result = '0;
        w_dp_op = ADD;
        w_a_fmt = OP_FMT_FP32;
        w_use_lane1 = 1'b0;
        unique case (i_issued_instr.instr.fpu_op)
            FPU_FADD:  w_dp_op = ADD;
            FPU_FSUB:  w_dp_op = SUB;
            FPU_FMUL:  w_dp_op = MUL;
            FPU_FSQRT: begin w_dp_op = SQRT; w_use_lane1 = 1'b1; end
            FPU_FMADD: w_dp_op = FMA;
            FPU_FMSUB: w_dp_op = FMS;
            FPU_FNMADD:w_dp_op = FNMA;
            FPU_FNMSUB:w_dp_op = FNMS;
            FPU_CVT_I2F: begin
                w_dp_op = CVTI2F;
                w_a_fmt = i_issued_instr.instr.raw[24:20] == 5'd1
                        ? OP_FMT_I32 : OP_FMT_I64;
            end
            FPU_CVT_F2I: w_dp_op = CVTF2I;
            FPU_FSGNJ: begin
                w_is_simple = 1'b1;
                w_simple_result = {32'd0, i_issued_instr.rs2_data[31],
                                   i_issued_instr.rs1_data[30:0]};
            end
            FPU_FSGNJN: begin
                w_is_simple = 1'b1;
                w_simple_result = {32'd0, ~i_issued_instr.rs2_data[31],
                                   i_issued_instr.rs1_data[30:0]};
            end
            FPU_FSGNJX: begin
                w_is_simple = 1'b1;
                w_simple_result = {32'd0,
                                   i_issued_instr.rs1_data[31] ^ i_issued_instr.rs2_data[31],
                                   i_issued_instr.rs1_data[30:0]};
            end
            FPU_FCMP_EQ: begin
                w_is_simple = 1'b1;
                w_simple_result = XLEN'(fp32_eq(i_issued_instr.rs1_data[31:0],
                                                i_issued_instr.rs2_data[31:0]));
            end
            FPU_FCMP_LT: begin
                w_is_simple = 1'b1;
                w_simple_result = XLEN'(fp32_lt(i_issued_instr.rs1_data[31:0],
                                                i_issued_instr.rs2_data[31:0]));
            end
            FPU_FCMP_LE: begin
                w_is_simple = 1'b1;
                w_simple_result = XLEN'(fp32_lt(i_issued_instr.rs1_data[31:0],
                                                i_issued_instr.rs2_data[31:0]) ||
                                              fp32_eq(i_issued_instr.rs1_data[31:0],
                                                i_issued_instr.rs2_data[31:0]));
            end
            FPU_FMIN: begin
                w_is_simple = 1'b1;
                w_simple_result = fp32_is_nan(i_issued_instr.rs1_data[31:0])
                    ? {32'd0, i_issued_instr.rs2_data[31:0]}
                    : fp32_is_nan(i_issued_instr.rs2_data[31:0])
                    ? {32'd0, i_issued_instr.rs1_data[31:0]}
                    : fp32_lt(i_issued_instr.rs2_data[31:0], i_issued_instr.rs1_data[31:0])
                    ? {32'd0, i_issued_instr.rs2_data[31:0]}
                    : {32'd0, i_issued_instr.rs1_data[31:0]};
            end
            FPU_FMAX: begin
                w_is_simple = 1'b1;
                w_simple_result = fp32_is_nan(i_issued_instr.rs1_data[31:0])
                    ? {32'd0, i_issued_instr.rs2_data[31:0]}
                    : fp32_is_nan(i_issued_instr.rs2_data[31:0])
                    ? {32'd0, i_issued_instr.rs1_data[31:0]}
                    : fp32_lt(i_issued_instr.rs1_data[31:0], i_issued_instr.rs2_data[31:0])
                    ? {32'd0, i_issued_instr.rs2_data[31:0]}
                    : {32'd0, i_issued_instr.rs1_data[31:0]};
            end
            FPU_FCLASS: begin
                w_is_simple = 1'b1;
                w_simple_result = XLEN'(fp32_class(i_issued_instr.rs1_data[31:0]));
            end
            default: begin
                w_is_simple = 1'b1;
                w_simple_result = '0;
            end
        endcase
    end

    /* The adapter admits one operation at a time.  Both datapath lanes are
     * therefore idle whenever this interface is ready; keeping ready
     * independent of valid also avoids a core/FIFO combinational loop. */
    assign o_req_ready = !r_busy && !r_result_valid;
    assign w_accept = i_req_valid && o_req_ready;
    assign w_dp_result_valid = w_l0_valid || w_l1_valid;
    assign w_dp_result = w_l1_valid ? w_l1_result : w_l0_result;
    /* The datapath represents add/sub as a*1+c; multiplication and fused
     * operations use their natural a,b,c operand positions. */
    assign w_dp_c = (i_issued_instr.instr.fpu_op == FPU_FADD ||
                     i_issued_instr.instr.fpu_op == FPU_FSUB)
                  ? i_issued_instr.rs2_data : i_issued_instr.rs3_data;

    fpu_datapath datapath (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_l0_in_valid(w_accept && !w_is_simple && !w_use_lane1),
        .o_l0_in_ready(w_l0_ready), .i_l0_op(w_dp_op),
        .i_l0_a_fmt(w_a_fmt), .i_l0_b_fmt(OP_FMT_FP32),
        .i_l0_c_fmt(OP_FMT_FP32), .i_l0_result_fmt(FMT_FP32),
        .i_l0_thrd(XLEN'(i_issued_instr.thrd_id)),
        .i_l0_a(i_issued_instr.rs1_data), .i_l0_b(i_issued_instr.rs2_data),
        .i_l0_c(w_dp_c), .i_l0_out_ready(1'b1),
        .o_l0_out_valid(w_l0_valid), .o_l0_thrd(w_l0_thrd),
        .o_l0_result(w_l0_result),
        .i_l1_in_valid(w_accept && !w_is_simple && w_use_lane1),
        .o_l1_in_ready(w_l1_ready), .i_l1_op(w_dp_op),
        .i_l1_a_fmt(w_a_fmt), .i_l1_b_fmt(OP_FMT_FP32),
        .i_l1_c_fmt(OP_FMT_FP32), .i_l1_result_fmt(FMT_FP32),
        .i_l1_thrd(XLEN'(i_issued_instr.thrd_id)),
        .i_l1_a(i_issued_instr.rs1_data), .i_l1_b(i_issued_instr.rs2_data),
        .i_l1_c(w_dp_c), .i_l1_out_ready(1'b1),
        .o_l1_out_valid(w_l1_valid), .o_l1_thrd(w_l1_thrd),
        .o_l1_result(w_l1_result)
    );

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_busy <= 1'b0;
            r_result_valid <= 1'b0;
            r_result_thrd <= '0;
            r_result <= '0;
        end else begin
            if (r_result_valid && i_res_ready)
                r_result_valid <= 1'b0;
            if (w_accept) begin
`ifdef DMCTP_FPU_TRACE
                $display("[FPUTRACE] req thrd=%0d op=%0d a=%016h b=%016h c=%016h simple=%0d",
                         i_issued_instr.thrd_id, i_issued_instr.instr.fpu_op,
                         i_issued_instr.rs1_data, i_issued_instr.rs2_data,
                         i_issued_instr.rs3_data, w_is_simple);
`endif
                if (w_is_simple) begin
                    r_result_valid <= 1'b1;
                    r_result_thrd <= i_issued_instr.thrd_id;
                    r_result <= w_simple_result;
                end else begin
                    r_busy <= 1'b1;
                end
            end
            if (w_dp_result_valid) begin
`ifdef VERILATOR
                $display("[FPUTRACE] result thrd=%0d value=%016h",
                         w_l1_valid ? w_l1_thrd : w_l0_thrd, w_dp_result);
`endif
                r_busy <= 1'b0;
                r_result_valid <= 1'b1;
                r_result_thrd <= w_l1_valid
                    ? w_l1_thrd[$clog2(NUM_HW_THRDS)-1:0]
                    : w_l0_thrd[$clog2(NUM_HW_THRDS)-1:0];
                r_result <= w_dp_result;
            end
        end
    end

    assign o_res_valid = r_result_valid;
    assign o_res_thrd_id = r_result_thrd;
    assign o_result = r_result;
endmodule: fpu
