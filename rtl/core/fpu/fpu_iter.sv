/*
 * fpu_iter.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 */

`timescale 1ps/1ps
`default_nettype none

import fpu_pkg::*;
import fpu_functions_pkg::*;
import isa_pkg::*;

module fp_iter (
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_l0_in_valid,
    output logic                o_l0_in_ready,
    input  fp_op_e              i_l0_op,
    input  opd_fmt_e            i_l0_a_fmt,
    input  opd_fmt_e            i_l0_b_fmt,
    input  opd_fmt_e            i_l0_c_fmt,
    input  fp_format_e          i_l0_result_fmt,
    input  logic [XLEN-1:0]     i_l0_thrd,
    input  logic [XLEN-1:0]     i_l0_a,
    input  logic [XLEN-1:0]     i_l0_b,
    input  logic [XLEN-1:0]     i_l0_c,
    input  logic                i_l0_out_ready,
    output logic                o_l0_out_valid,
    output logic [XLEN-1:0]     o_l0_thrd,
    output logic [XLEN-1:0]     o_l0_result,
    input  logic                i_l1_in_valid,
    output logic                o_l1_in_ready,
    input  fp_op_e              i_l1_op,
    input  opd_fmt_e            i_l1_a_fmt,
    input  opd_fmt_e            i_l1_b_fmt,
    input  opd_fmt_e            i_l1_c_fmt,
    input  fp_format_e          i_l1_result_fmt,
    input  logic [XLEN-1:0]     i_l1_thrd,
    input  logic [XLEN-1:0]     i_l1_a,
    input  logic [XLEN-1:0]     i_l1_b,
    input  logic [XLEN-1:0]     i_l1_c,
    input  logic                i_l1_out_ready,
    output logic                o_l1_out_valid,
    output logic [XLEN-1:0]     o_l1_thrd,
    output logic [XLEN-1:0]     o_l1_result,
    output logic                o_is_iter_own_p0,
    output logic                o_is_iter_own_p1,
    output logic                o_p0_in_valid,
    output fp_op_e              o_p0_op,
    output opd_fmt_e            o_p0_a_fmt,
    output opd_fmt_e            o_p0_b_fmt,
    output opd_fmt_e            o_p0_c_fmt,
    output fp_format_e          o_p0_result_fmt,
    output logic [XLEN-1:0]     o_p0_thrd,
    output logic [XLEN-1:0]     o_p0_a,
    output logic [XLEN-1:0]     o_p0_b,
    output logic [XLEN-1:0]     o_p0_c,
    input  logic                i_p0_out_valid,
    input  logic [XLEN-1:0]     i_p0_thrd,
    input  logic [XLEN-1:0]     i_p0_result,
    output logic                o_p1_in_valid,
    output fp_op_e              o_p1_op,
    output opd_fmt_e            o_p1_a_fmt,
    output opd_fmt_e            o_p1_b_fmt,
    output opd_fmt_e            o_p1_c_fmt,
    output fp_format_e          o_p1_result_fmt,
    output logic [XLEN-1:0]     o_p1_thrd,
    output logic [XLEN-1:0]     o_p1_a,
    output logic [XLEN-1:0]     o_p1_b,
    output logic [XLEN-1:0]     o_p1_c,
    input  logic                i_p1_out_valid,
    input  logic [XLEN-1:0]     i_p1_thrd,
    input  logic [XLEN-1:0]     i_p1_result
);
    localparam logic [XLEN-5:0] ITER_THRD_PREFIX = '1;

    iter_state_e           r_state;
    iter_state_e           w_state_next;
    iter_request_t         r_request;
    iter_ctr_t             r_iter_ctr;
    iter_limit_t           r_iter_limit;

    fp_bits_t              r_x;
    fp_bits_t              r_divisor;
    fp_bits_t              r_seed;
    fp_bits_t              r_num;
    fp_bits_t              r_den;
    fp_bits_t              r_factor;
    fp_bits_t              r_sqrt_x;
    fp_bits_t              r_product;
    fp_bits_t              r_sqrt_h;
    logic [XLEN-1:0]       r_result;

    logic                  r_have_num;
    logic                  r_have_den;
    logic                  r_have_factor;
    logic                  r_have_sqrt_x;
    logic                  r_have_product;
    logic                  r_have_root;
    logic                  r_have_half;

    /*
     * Request prepare
     */
    fp_ir_t                w_a_ir;
    fp_ir_t                w_b_ir;
    fp_bits_t              w_a_fp32;
    fp_bits_t              w_b_fp32;
    special_result_t       w_special_result;
    logic                  w_l0_iter;
    logic                  w_l1_iter;
    logic                  w_iter_accept;

    always_comb begin: request_prepare
        w_a_ir          = operand_to_ir(i_l1_a, i_l1_a_fmt);
        w_b_ir          = operand_to_ir(i_l1_b, i_l1_b_fmt);
        w_a_fp32        = operand_to_fp32(i_l1_a, i_l1_a_fmt);
        w_b_fp32        = operand_to_fp32(i_l1_b, i_l1_b_fmt);
        w_special_result = iter_special_case(i_l1_op, w_a_ir, w_b_ir,
                                             i_l1_result_fmt);
        w_l0_iter       = i_l0_op == DIV || i_l0_op == SQRT;
        w_l1_iter       = i_l1_op == DIV || i_l1_op == SQRT;
        w_iter_accept   = r_state == ITER_IDLE && i_l1_in_valid
                        && w_l1_iter;
    end: request_prepare

    /*
     * Pipe result identify
     */
    logic                  w_p0_iter_result;
    logic                  w_p1_iter_result;
    logic                  w_num_return;
    logic                  w_den_return;
    logic                  w_factor_return;
    logic                  w_sqrt_x_return;
    logic                  w_product_return;
    logic                  w_root_return;
    logic                  w_half_return;
    iter_tag_e             w_p0_tag;
    iter_tag_e             w_p1_tag;

    always_comb begin: result_identify
        w_p0_iter_result = i_p0_out_valid
                         && i_p0_thrd[XLEN-1:4] == ITER_THRD_PREFIX;
        w_p1_iter_result = i_p1_out_valid
                         && i_p1_thrd[XLEN-1:4] == ITER_THRD_PREFIX;
        w_p0_tag          = iter_tag_e'(i_p0_thrd[3:0]);
        w_p1_tag          = iter_tag_e'(i_p1_thrd[3:0]);
        w_num_return      = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_DIV_NUM)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_DIV_NUM);
        w_den_return      = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_DIV_DEN)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_DIV_DEN);
        w_factor_return   = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_SQ_FACTOR)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_SQ_FACTOR);
        w_sqrt_x_return   = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_SQ_INIT)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_SQ_INIT);
        w_product_return  = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_SQ_PRODUCT)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_SQ_PRODUCT);
        w_root_return     = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_SQ_ROOT)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_SQ_ROOT);
        w_half_return     = (w_p0_iter_result
                          && w_p0_tag == ITER_TAG_SQ_HALF)
                          || (w_p1_iter_result
                          && w_p1_tag == ITER_TAG_SQ_HALF);
    end: result_identify

    /*
     * Returned values
     */
    fp_bits_t              w_num_value;
    fp_bits_t              w_den_value;
    fp_bits_t              w_factor_value;
    fp_bits_t              w_sqrt_x_value;
    fp_bits_t              w_product_value;
    fp_bits_t              w_root_value;
    fp_bits_t              w_half_value;

    always_comb begin: result_select
        w_num_value     = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_DIV_NUM
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_den_value     = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_DIV_DEN
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_factor_value  = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_SQ_FACTOR
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_sqrt_x_value  = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_SQ_INIT
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_product_value = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_SQ_PRODUCT
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_root_value    = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_SQ_ROOT
                        ? i_p0_result[31:0] : i_p1_result[31:0];
        w_half_value    = w_p0_iter_result
                       && w_p0_tag == ITER_TAG_SQ_HALF
                        ? i_p0_result[31:0] : i_p1_result[31:0];
    end: result_select

    /*
     * for iter use the two lanes staergicaly it is gurateed that
     * the div/sqrt come to the lane1 only
     * so block the lane1 while coputing
     */

    /*
     * Pipe issue defaults
     */
    always_comb begin: pipe_issue
        o_p0_in_valid   = 1'b0;
        o_p0_op         = MUL;
        o_p0_a_fmt      = OP_FMT_FP32;
        o_p0_b_fmt      = OP_FMT_FP32;
        o_p0_c_fmt      = OP_FMT_FP32;
        o_p0_result_fmt = FMT_FP32;
        o_p0_thrd       = '0;
        o_p0_a          = '0;
        o_p0_b          = '0;
        o_p0_c          = '0;
        o_p1_in_valid   = 1'b0;
        o_p1_op         = MUL;
        o_p1_a_fmt      = OP_FMT_FP32;
        o_p1_b_fmt      = OP_FMT_FP32;
        o_p1_c_fmt      = OP_FMT_FP32;
        o_p1_result_fmt = FMT_FP32;
        o_p1_thrd       = '0;
        o_p1_a          = '0;
        o_p1_b          = '0;
        o_p1_c          = '0;
        w_state_next    = r_state;

        unique case (r_state)
            /*
             * Request accept
             */
            ITER_IDLE: begin
                if (w_iter_accept) begin
                    w_state_next = w_special_result[32] ? ITER_DONE
                                 : i_l1_op == DIV ? ITER_DIV_INIT
                                 : ITER_SQ_MUL;
                end
            end

            /*
             * Division initialize
             */
            ITER_DIV_INIT: begin
                o_p1_in_valid = 1'b1;
                o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_DIV_NUM};
                o_p1_a        = {32'b0, r_x};
                o_p1_b        = {32'b0, r_seed};
                if (!i_l0_in_valid) begin
                    o_p0_in_valid = 1'b1;
                    o_p0_thrd     = {ITER_THRD_PREFIX, ITER_TAG_DIV_DEN};
                    o_p0_a        = {32'b0, r_den};
                    o_p0_b        = {32'b0, r_seed};
                    w_state_next  = ITER_DIV_INIT_WAIT;
                end else begin
                    w_state_next  = ITER_DIV_INIT_SECOND;
                end
            end
            ITER_DIV_INIT_SECOND: begin
                o_p1_in_valid = 1'b1;
                o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_DIV_DEN};
                o_p1_a        = {32'b0, r_den};
                o_p1_b        = {32'b0, r_seed};
                w_state_next  = ITER_DIV_INIT_WAIT;
            end
            ITER_DIV_INIT_WAIT: begin
                if ((r_have_num || w_num_return)
                 && (r_have_den || w_den_return)) begin
                    o_p1_in_valid = 1'b1;
                    o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_DIV_NUM};
                    o_p1_a        = {32'b0, w_num_return
                                    ? w_num_value : r_num};
                    o_p1_b        = {32'b0, goldschmidt_div_factor(
                                     w_den_return ? w_den_value : r_den)};
                    if (!i_l0_in_valid) begin
                        o_p0_in_valid = 1'b1;
                        o_p0_thrd     = {ITER_THRD_PREFIX,
                                         ITER_TAG_DIV_DEN};
                        o_p0_a        = {32'b0, w_den_return
                                        ? w_den_value : r_den};
                        o_p0_b        = {32'b0, goldschmidt_div_factor(
                                         w_den_return
                                         ? w_den_value : r_den)};
                        w_state_next  = ITER_DIV_UPDATE_WAIT;
                    end else begin
                        w_state_next  = ITER_DIV_UPDATE_SECOND;
                    end
                end
            end

            /*
             * Division iterate
             */
            ITER_DIV_UPDATE_SECOND: begin
                o_p1_in_valid = 1'b1;
                o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_DIV_DEN};
                o_p1_a        = {32'b0, r_den};
                o_p1_b        = {32'b0, r_factor};
                w_state_next  = ITER_DIV_UPDATE_WAIT;
            end
            ITER_DIV_UPDATE_WAIT: begin
                if ((r_have_num || w_num_return)
                 && (r_have_den || w_den_return)) begin
                    if (r_iter_ctr
                     == iter_ctr_t'(r_iter_limit-1'b1)) begin
                        w_state_next = ITER_DONE;
                    end else begin
                        o_p1_in_valid = 1'b1;
                        o_p1_thrd     = {ITER_THRD_PREFIX,
                                         ITER_TAG_DIV_NUM};
                        o_p1_a        = {32'b0, w_num_return
                                        ? w_num_value : r_num};
                        o_p1_b        = {32'b0, goldschmidt_div_factor(
                                         w_den_return
                                         ? w_den_value : r_den)};
                        if (!i_l0_in_valid) begin
                            o_p0_in_valid = 1'b1;
                            o_p0_thrd     = {ITER_THRD_PREFIX,
                                             ITER_TAG_DIV_DEN};
                            o_p0_a        = {32'b0, w_den_return
                                            ? w_den_value : r_den};
                            o_p0_b        = {32'b0,
                                             goldschmidt_div_factor(
                                             w_den_return
                                             ? w_den_value : r_den)};
                            w_state_next  = ITER_DIV_UPDATE_WAIT;
                        end else begin
                            w_state_next  = ITER_DIV_UPDATE_SECOND;
                        end
                    end
                end
            end

            /*
             * Square root iterate
             */
            ITER_SQ_MUL: begin
                o_p1_in_valid = 1'b1;
                o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_SQ_INIT};
                o_p1_a        = {32'b0, r_x};
                o_p1_b        = {32'b0, r_seed};
                w_state_next  = ITER_SQ_MUL_WAIT;
            end
            ITER_SQ_MUL_WAIT: begin
                if (r_have_sqrt_x || w_sqrt_x_return) begin
                    o_p1_in_valid = 1'b1;
                    o_p1_thrd     = {ITER_THRD_PREFIX,
                                     ITER_TAG_SQ_PRODUCT};
                    o_p1_a        = {32'b0, w_sqrt_x_return
                                    ? w_sqrt_x_value : r_sqrt_x};
                    o_p1_b        = {32'b0, r_sqrt_h};
                    w_state_next  = ITER_SQ_PRODUCT_WAIT;
                end
            end
            ITER_SQ_PRODUCT_WAIT: begin
                if (r_have_product || w_product_return) begin
                    o_p1_in_valid = 1'b1;
                    o_p1_op       = SUB;
                    o_p1_thrd     = {ITER_THRD_PREFIX,
                                     ITER_TAG_SQ_FACTOR};
                    o_p1_a        = 64'h0000_0000_3fc0_0000;
                    o_p1_b        = 64'h0000_0000_3f80_0000;
                    o_p1_c        = {32'b0, w_product_return
                                    ? w_product_value : r_product};
                    w_state_next  = ITER_SQ_FACTOR_WAIT;
                end
            end
            ITER_SQ_FACTOR_WAIT: begin
                if (r_have_factor || w_factor_return) begin
                    o_p1_in_valid = 1'b1;
                    o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_SQ_ROOT};
                    o_p1_a        = {32'b0, r_sqrt_x};
                    o_p1_b        = {32'b0, w_factor_return
                                    ? w_factor_value : r_factor};
                    if (!i_l0_in_valid) begin
                        o_p0_in_valid = 1'b1;
                        o_p0_thrd     = {ITER_THRD_PREFIX,
                                         ITER_TAG_SQ_HALF};
                        o_p0_a        = {32'b0, r_sqrt_h};
                        o_p0_b        = {32'b0, w_factor_return
                                        ? w_factor_value : r_factor};
                        w_state_next  = ITER_SQ_UPDATE_WAIT;
                    end else begin
                        w_state_next  = ITER_SQ_UPDATE_SECOND;
                    end
                end
            end
            ITER_SQ_UPDATE_SECOND: begin
                o_p1_in_valid = 1'b1;
                o_p1_thrd     = {ITER_THRD_PREFIX, ITER_TAG_SQ_HALF};
                o_p1_a        = {32'b0, r_sqrt_h};
                o_p1_b        = {32'b0, r_factor};
                w_state_next  = ITER_SQ_UPDATE_WAIT;
            end
            ITER_SQ_UPDATE_WAIT: begin
                if ((r_have_root || w_root_return)
                 && (r_have_half || w_half_return)) begin
                    if (r_iter_ctr
                     == iter_ctr_t'(r_iter_limit-1'b1)) begin
                        w_state_next = ITER_DONE;
                    end else begin
                        o_p1_in_valid = 1'b1;
                        o_p1_thrd     = {ITER_THRD_PREFIX,
                                         ITER_TAG_SQ_PRODUCT};
                        o_p1_a        = {32'b0, w_root_return
                                        ? w_root_value : r_sqrt_x};
                        o_p1_b        = {32'b0, w_half_return
                                        ? w_half_value : r_sqrt_h};
                        w_state_next  = ITER_SQ_PRODUCT_WAIT;
                    end
                end
            end

            /*
             * Result complete
             */
            ITER_DONE: begin
                if (i_l1_out_ready) begin
                    w_state_next = ITER_IDLE;
                end
            end
            default: w_state_next = ITER_IDLE;
        endcase
    end: pipe_issue

    /*
     * Iteration registers
     */
    always_ff @(posedge i_clk) begin: iteration_ff
        if (!i_rst_n) begin
            r_state        <= ITER_IDLE;
            r_request      <= '0;
            r_iter_ctr     <= '0;
            r_iter_limit   <= iter_limit_t'(ITER_MAX_ITERS);
            r_x            <= '0;
            r_divisor      <= '0;
            r_seed         <= '0;
            r_num          <= '0;
            r_den          <= '0;
            r_factor       <= '0;
            r_sqrt_x       <= '0;
            r_product      <= '0;
            r_sqrt_h       <= '0;
            r_result       <= '0;
            r_have_num     <= 1'b0;
            r_have_den     <= 1'b0;
            r_have_factor  <= 1'b0;
            r_have_sqrt_x  <= 1'b0;
            r_have_product <= 1'b0;
            r_have_root    <= 1'b0;
            r_have_half    <= 1'b0;
        end else begin
            r_state <= w_state_next;

            /*
             * Request capture
             */
            if (w_iter_accept) begin
                r_request.op         <= i_l1_op;
                r_request.result_fmt <= i_l1_result_fmt;
                r_request.thrd       <= i_l1_thrd;
                r_request.result_sgn <= i_l1_op == DIV
                                      ? w_a_ir.sgn ^ w_b_ir.sgn : 1'b0;
                r_iter_ctr           <= '0;
                r_iter_limit         <= iteration_limit(i_l1_result_fmt);
                r_x                  <= {1'b0, w_a_fp32[30:0]};
                r_divisor            <= {1'b0, w_b_fp32[30:0]};
                r_den                <= {1'b0, w_b_fp32[30:0]};
                r_seed               <= seed_table_lookup(
                                        i_l1_op == DIV ? w_b_fp32 : w_a_fp32,
                                        i_l1_op == SQRT);
                r_sqrt_h             <= fp32_half(seed_table_lookup(
                                        w_a_fp32, 1'b1));
                if (w_special_result[32]) begin
                    r_result <= {{(XLEN-32){1'b0}},
                                 w_special_result[31:0]};
                end
            end

            /*
             * Pipe result capture
             */
            if (w_num_return) begin
                r_num      <= w_num_value;
                r_have_num <= 1'b1;
            end
            if (w_den_return) begin
                r_den      <= w_den_value;
                r_have_den <= 1'b1;
            end
            if (w_factor_return) begin
                r_factor      <= w_factor_value;
                r_have_factor <= 1'b1;
            end
            if (w_sqrt_x_return) begin
                r_sqrt_x      <= w_sqrt_x_value;
                r_have_sqrt_x <= 1'b1;
            end
            if (w_product_return) begin
                r_product      <= w_product_value;
                r_have_product <= 1'b1;
            end
            if (w_root_return) begin
                r_sqrt_x    <= w_root_value;
                r_have_root <= 1'b1;
            end
            if (w_half_return) begin
                r_sqrt_h    <= w_half_value;
                r_have_half <= 1'b1;
            end
            if (o_p1_in_valid
             && iter_tag_e'(o_p1_thrd[3:0]) == ITER_TAG_DIV_NUM
             && (r_state == ITER_DIV_INIT_WAIT
              || r_state == ITER_DIV_UPDATE_WAIT)) begin
                r_factor <= o_p1_b[31:0];
            end

            /*
             * Result flags clear on the next pipe issue
             */
            if (o_p1_in_valid) begin
                unique case (iter_tag_e'(o_p1_thrd[3:0]))
                    ITER_TAG_DIV_NUM: begin
                        r_have_num <= 1'b0;
                        if (o_p0_in_valid) begin
                            r_have_den <= 1'b0;
                        end
                    end
                    ITER_TAG_DIV_DEN: begin
                        r_have_den <= 1'b0;
                    end
                    ITER_TAG_SQ_FACTOR: begin
                        r_have_factor <= 1'b0;
                    end
                    ITER_TAG_SQ_INIT: begin
                        r_have_sqrt_x <= 1'b0;
                    end
                    ITER_TAG_SQ_PRODUCT: begin
                        r_have_product <= 1'b0;
                    end
                    ITER_TAG_SQ_ROOT: begin
                        r_have_root <= 1'b0;
                        if (o_p0_in_valid) begin
                            r_have_half <= 1'b0;
                        end
                    end
                    ITER_TAG_SQ_HALF: begin
                        r_have_half <= 1'b0;
                    end
                    default: begin
                    end
                endcase
            end

            /*
             * Division complete
             */
            if (r_state == ITER_DIV_UPDATE_WAIT
             && (r_have_num || w_num_return)
             && (r_have_den || w_den_return)) begin
                if (r_iter_ctr == iter_ctr_t'(r_iter_limit-1'b1)) begin
                    r_result <= {{(XLEN-32){1'b0}}, iter_round_result(
                                 final_correction(
                                 w_num_return ? w_num_value : r_num,
                                 r_x, r_divisor),
                                 r_request.result_sgn,
                                 r_request.result_fmt)};
                end else begin
                    r_iter_ctr <= r_iter_ctr + 1'b1;
                end
            end

            /*
             * Square root complete
             */
            if (r_state == ITER_SQ_UPDATE_WAIT
             && (r_have_root || w_root_return)
             && (r_have_half || w_half_return)) begin
                if (r_iter_ctr == iter_ctr_t'(r_iter_limit-1'b1)) begin
                    r_result <= {{(XLEN-32){1'b0}}, iter_round_result(
                                 sqrt_final_correction(
                                 w_root_return ? w_root_value : r_sqrt_x,
                                 r_x), 1'b0, r_request.result_fmt)};
                end else begin
                    r_iter_ctr <= r_iter_ctr + 1'b1;
                end
            end
        end
    end: iteration_ff

    /*
     * Output mux
     */
    always_comb begin: output_mux
        o_l0_out_valid = i_p0_out_valid && !w_p0_iter_result;
        o_l0_thrd      = i_p0_thrd;
        o_l0_result    = i_p0_result;
        o_l1_out_valid = i_p1_out_valid && !w_p1_iter_result;
        o_l1_thrd      = i_p1_thrd;
        o_l1_result    = i_p1_result;
        if (r_state == ITER_DONE) begin
            o_l1_out_valid = 1'b1;
            o_l1_thrd      = r_request.thrd;
            o_l1_result    = r_result;
        end
    end: output_mux

    /*
     * Input mux
     */
    always_comb begin: input_mux
        o_is_iter_own_p0 = o_p0_in_valid;
        o_is_iter_own_p1 = r_state != ITER_IDLE
                         || (i_l1_in_valid && w_l1_iter);
        o_l0_in_ready    = !w_l0_iter;
        o_l1_in_ready    = r_state == ITER_IDLE;
    end: input_mux

    /*
     * the round is implemented using a local rounder dont reuse the pipe0/1
     */
endmodule: fp_iter

`default_nettype wire
