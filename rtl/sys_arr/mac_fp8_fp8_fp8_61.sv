/*
 * mac_fp8_fp8_fp8_61.sv
 * 
 * Copyright (C) 2025 Sathsara Geeth
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

`timescale 1ns/1ps
`default_nettype none
/* S1E4M3
* Pipe chars: Stiff, 6 cycle latency.
**/

import mac_fp8_fp8_fp8_61_cnfg_pkg::*;
import sys_cnfg_pkg::*;

module mac_fp8_fp8_fp8_61
(
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_en,
    input  logic                    i_clr_n,
    input  logic                    i_start,
    input  logic                    i_last,
    output logic                    o_done,
    input  logic [$clog2(M+1)-1:0]  i_dim,
    input  logic [8-1:0]            i_a,
    input  logic [8-1:0]            i_b,
    output logic [8-1:0]            o_d
);
    // Stage 0 (Unpack, colapsed) >>>
    logic                           w_s1_a_sgn;
    logic [3:0]                     w_s1_a_exp;
    logic [2:0]                     w_s1_a_man;
    logic                           w_s1_b_sgn;
    logic [3:0]                     w_s1_b_exp;
    logic [2:0]                     w_s1_b_man;
    logic [3:0]                     w_s1_a_man_ext;
    logic [3:0]                     w_s1_b_man_ext;

    logic                           w_s1_start;
    ///////////////////////////////////////////////
    assign {w_s1_a_sgn, w_s1_a_exp, w_s1_a_man} = i_a;
    assign {w_s1_b_sgn, w_s1_b_exp, w_s1_b_man} = i_b;
    assign w_s1_a_man_ext                       = (w_s1_a_exp != 4'b0000) ? {1'b1, w_s1_a_man} : 4'b0000;     // flush denormals to zero
    assign w_s1_b_man_ext                       = (w_s1_b_exp != 4'b0000) ? {1'b1, w_s1_b_man} : 4'b0000;
    assign w_s1_start                           = i_start;
    
    ///////////////////////////////////////////////
    // Stage 1 (a*b mat mul & exp add) >>>
    logic signed [5:0]              w_s2_ab_sum_exp;
    logic [7:0]                     w_s2_ab_mul_man;
    logic                           w_s2_ab_sgn;
    logic                           w_s2_start;
    ///////////////////////////////////////////////
    always_ff @(posedge i_clk or negedge i_rst_n) begin: pr_s1_s2
        if (!i_rst_n || !i_clr_n) begin
            w_s2_ab_sum_exp    <= '0;
            w_s2_ab_mul_man    <= '0;
            w_s2_ab_sgn        <= 1'b0;
            w_s2_start         <= 1'b0;
        end else if (i_en) begin
            w_s2_ab_sum_exp    <= $signed({2'b0, w_s1_a_exp}) + $signed({2'b0, w_s1_b_exp}) - $signed(6'(EXP_BIAS));
            w_s2_ab_mul_man    <= w_s1_a_man_ext * w_s1_b_man_ext;
            w_s2_ab_sgn        <= w_s1_a_sgn ^ w_s1_b_sgn;
            w_s2_start         <= w_s1_start;
        end
    end: pr_s1_s2

    ///////////////////////////////////////////////
    // Stage 2 (algn a*b) >>>
    logic [INTL_W-1:0]              w_s3_aligned_ab;
    logic                           w_s3_ab_sgn;     
    logic                           w_s3_start;
    logic                           w_s3_lane_id;
    /////////////////////////////////////////////// 
    logic [INTL_W-1:0]              w_s2_aligned_ab;
    logic signed [6:0]              w_s2_shift;

    assign w_s2_shift      = 7'($signed(w_s2_ab_sum_exp)) + 7'($signed(SHIFT_OFFSET));
    assign w_s2_aligned_ab = (w_s2_shift >= $signed(7'(INTL_W))) ? '0 :
                             (w_s2_shift >= 0) ?
                             (INTL_W'({{(INTL_W-8){1'b0}}, w_s2_ab_mul_man}) << w_s2_shift) :
                             (INTL_W'({{(INTL_W-8){1'b0}}, w_s2_ab_mul_man}) >> (-w_s2_shift));    

    always_ff @(posedge i_clk or negedge i_rst_n) begin: pr_s2_s3
        if (!i_rst_n || !i_clr_n) begin
            w_s3_aligned_ab     <= '0;
            w_s3_ab_sgn         <= '0;
            w_s3_start          <= 1'b0;
            w_s3_lane_id        <= 1'b0;
        end else if (i_en) begin
            w_s3_aligned_ab     <= w_s2_aligned_ab;
            w_s3_ab_sgn         <= w_s2_ab_sgn;
            w_s3_start          <= w_s2_start;
            if (w_s2_start) begin
                w_s3_lane_id <= ~w_s3_lane_id;
            end
        end
    end: pr_s2_s3

    ///////////////////////////////////////////////
    // Stage 3 (palce sgned a*b in acc) >>>
    logic [INTL_W-1:0]              w_s4_0_acc;
    logic [INTL_W-1:0]              w_s4_1_acc;
    logic                           w_s4_lane_id;
    logic [INTL_W-1:0]              w_s4_add_in;
    ///////////////////////////////////////////////
    assign w_s4_add_in = w_s3_ab_sgn ? (~w_s3_aligned_ab + 1) : w_s3_aligned_ab;

    always_ff @(posedge i_clk or negedge i_rst_n) begin: pr_s3_s4
        if (!i_rst_n || !i_clr_n) begin
            w_s4_0_acc     <= '0;
            w_s4_lane_id   <= 1'b0;
        end else if (i_en) begin
            if (!w_s3_lane_id) begin
                w_s4_0_acc <= w_s3_start ? w_s4_add_in : (w_s4_0_acc + w_s4_add_in);
            end else begin
                w_s4_1_acc <= w_s3_start ? w_s4_add_in : (w_s4_1_acc + w_s4_add_in);
            end
            w_s4_lane_id   <= w_s3_lane_id;
        end
    end: pr_s3_s4

    ///////////////////////////////////////////////
    // Stage 4 (lza) >>>
    logic [5:0]                     w_s5_lza;
    logic                           w_s5_sgn;
    logic [INTL_W-1:0]              w_s5_abs_val;
    ///////////////////////////////////////////////
    logic [5:0]                     w_s4_lza;               
    logic [INTL_W-1:0]              w_s4_lza_vec;

    logic [INTL_W-1:0]              w_s4_acc;

    assign w_s4_acc = w_s4_lane_id ? w_s4_0_acc : w_s4_1_acc;

    always_comb begin: lza
        w_s4_lza_vec = w_s4_acc ^ {w_s4_acc[INTL_W-2:0], ~w_s4_acc[INTL_W-1]};
        w_s4_lza = 6'd0;
        for (int i = INTL_W-1; i >= 0; i--) begin
            if (w_s4_lza_vec[i]) begin 
                w_s4_lza = i[5:0]; 
                break;
            end
        end
    end: lza

    always_ff @(posedge i_clk or negedge i_rst_n) begin: pr_s4_s5
        if (!i_rst_n || !i_clr_n) begin
            w_s5_sgn     <= 1'b0;
            w_s5_lza     <= '0;
            w_s5_abs_val <= '0;
        end else if (i_en) begin
            w_s5_sgn     <= w_s4_acc[INTL_W-1];
            w_s5_lza     <= w_s4_lza;
            w_s5_abs_val <= w_s4_acc[INTL_W-1] ? (~w_s4_acc + INTL_W'(1)) : w_s4_acc;
        end
    end: pr_s4_s5

    ///////////////////////////////////////////////
    // Stage 5 (Saturate, Correct and Pack) >>>
    logic [7:0]                     w_s6_res;
    ///////////////////////////////////////////////
    logic [INTL_W-1:0]              w_s5_norm_pre;
    logic [INTL_W-1:0]              w_s5_norm_vec;
    logic [5:0]                     w_s5_lza_corr;
    logic [7:0]                     w_s5_res;

    always_comb begin
        logic [3:0] w_mant_rnd;
        logic [5:0] w_lza_rnd;
        logic       w_round_up;
        logic [5:0] w_exp_out;

        w_s5_norm_pre = w_s5_abs_val << (6'(INTL_W - 1) - w_s5_lza);

        // lza correction
        if (w_s5_norm_pre[INTL_W-1]) begin
            w_s5_lza_corr = w_s5_lza;
            w_s5_norm_vec = w_s5_norm_pre;
        end else if (w_s5_norm_pre[INTL_W-2]) begin
            w_s5_lza_corr = w_s5_lza - 6'd1;
            w_s5_norm_vec = {w_s5_norm_pre[INTL_W-2:0], 1'b0};
        end else begin
            w_s5_lza_corr = w_s5_lza - 6'd2;
            w_s5_norm_vec = {w_s5_norm_pre[INTL_W-3:0], 2'b0};
        end

        // RNE: round up = G & (LSB | R | S)
        w_round_up = w_s5_norm_vec[G_BIT] &  (w_s5_norm_vec[MAN_B0] | w_s5_norm_vec[R_BIT] | (|w_s5_norm_vec[STICKY_LSB:0]));
        w_mant_rnd = {1'b0, w_s5_norm_vec[MAN_B2:MAN_B0]} + {3'b0, w_round_up};
        w_lza_rnd  = w_mant_rnd[3] ? (w_s5_lza_corr + 6'd1) : w_s5_lza_corr;

        // exponent recovery and saturation
        w_exp_out  = (w_lza_rnd > 6'(EXP_MAP_CONST)) ? (w_lza_rnd - 6'(EXP_MAP_CONST)) : 6'd0;
        
        if (w_s5_abs_val == '0 || w_lza_rnd >= 6'(INTL_W) || w_lza_rnd <= 6'(EXP_MAP_CONST)) begin
            w_s5_res = 8'b0;                                        // zero or underflow
        end else if (w_exp_out > 6'(EXP_MAX)) begin
            w_s5_res = {w_s5_sgn, 4'b1110, 3'b111};                 // saturate
        end else begin
            w_s5_res = {w_s5_sgn, w_exp_out[3:0], w_mant_rnd[2:0]};
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin: pr_s5_s6
        if (!i_rst_n || !i_clr_n) begin
            w_s6_res    <= '0;
        end else if (i_en) begin
            w_s6_res    <= w_s5_res;
        end
    end: pr_s5_s6

    ///////////////////////////////////////////////
    assign o_d = w_s6_res;

    logic [$clog2(M+1)-1:0] r_dim_latched;
    logic [$clog2(M+1)-1:0] r_done_ctr;
    logic                   r_counting;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_dim_latched <= '0;
            r_done_ctr    <= '0;
            r_counting    <= 1'b0;
            o_done        <= 1'b0;
        end else if (!i_clr_n) begin
            r_dim_latched <= '0;
            r_done_ctr    <= '0;
            r_counting    <= 1'b0;
            o_done        <= 1'b0;
        end else if (i_en) begin
            o_done <= 1'b0;
            if (i_last) begin
                r_dim_latched <= i_dim;
                r_counting    <= 1'b1;
                r_done_ctr    <= '0;
            end
            
            if (r_counting || i_last) begin
                if (r_done_ctr == (i_last ? i_dim : r_dim_latched) + 5'd4) begin
                    r_counting <= 1'b0;
                    o_done     <= 1'b1;
                end else begin
                    r_done_ctr <= r_done_ctr + 1'b1;
                end
            end
        end
    end
    ///////////////////////////////////////////////    
endmodule: mac_fp8_fp8_fp8_61
