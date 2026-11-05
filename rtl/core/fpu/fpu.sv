/*
 * Comments:
 * 1. Architecture:
 *    A) [ma] - 2 fma pipes on an ir (which also do add/sub/mul/fms/fns/fnm)
 *    B) 2 pipes for cmp & min max on an ir
 *    C) 2 pipes for convertions 
 *    D) a div on an ir, a sqrt on an ir using those 2 fma lanes opportunistically
 *    E) for fma {a,b,c} for add {a,c} for single {a}
 *    F) only lane 1 can do sqrt/div even though may help to compute if it is free
 *       but intertive ops never blocks lane 0
 *    G) so II_{lane0} = 1, always. II_{lane1} = 1 if not blocked
 * 2. up to 64bit integers are accepted and fp upto 32bit
 */

`timescale 1ps/1ps
`default_nettype none
import fpu_pkg::*;
import fpu_functions_pkg::*;
import isa_pkg::*;

module fpu_datapath (
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
    output logic [XLEN-1:0]     o_l1_result
);
    localparam int NUM_LANES = 2;

    for (genvar i = 0; i < NUM_LANES; i++) begin: lane
        logic w_lane_clk;
        logic w_lane_rst_n;

        /* 
         * p0:fma
         * p1:cmp/min/max
         * p2:convertions
         */
        
        /* 
         * s0---
         * p0s0: convert to ir & alignment
         * p1s0: convert to ir & unsigned field compare
         * p2s0: convert to ir & LZC
         */
        
        fp_ir_t                 w_s1_a;
        fp_ir_t                 w_s1_b;
        fp_ir_t                 w_s1_c;
        logic                   w_s1_valid;
        logic [XLEN-1:0]        w_s1_thrd;
        fp_op_e                 w_s1_fp_op;
        opd_fmt_e               w_s1_a_opd_fmt;
        opd_fmt_e               w_s1_b_opd_fmt;
        opd_fmt_e               w_s1_c_opd_fmt;
        fp_format_e             w_s1_result_fmt;
        logic [LCZ_W-1:0]       w_s1_lzc_a;
        

        logic [XLEN-1:0]        w_s0_a;
        fp_ir_t                 w_s0_a_ir;
        logic [XLEN-1:0]        w_s0_b;
        fp_ir_t                 w_s0_b_ir;
        logic [XLEN-1:0]        w_s0_c;
        fp_ir_t                 w_s0_c_ir;
        logic                   w_s0_valid;
        logic [XLEN-1:0]        w_s0_thrd;
        fp_op_e                 w_s0_fp_op;
        opd_fmt_e               w_s0_a_opd_fmt;
        opd_fmt_e               w_s0_b_opd_fmt;
        opd_fmt_e               w_s0_c_opd_fmt;
        fp_format_e             w_s0_result_fmt;
        logic [LCZ_W-1:0]       w_s0_lzc_a;
        

        /*
         * do not directly connect w_s0_* to inputs
         */

        always_comb begin: cvt2ir
            unique case (w_s0_a_opd_fmt)
                OP_FMT_FP32    : w_s0_a_ir = fp32_to_ir(w_s0_a[31:0]);
                OP_FMT_FP16    : w_s0_a_ir = fp16_to_ir(w_s0_a[31:0]);
                OP_FMT_FP8_E4M3: w_s0_a_ir = fp8_to_ir(w_s0_a[31:0]);
                OP_FMT_BF16    : w_s0_a_ir = bf16_to_ir(w_s0_a[31:0]);
                OP_FMT_FP8_E5M2: w_s0_a_ir = fp8_e5m2_to_ir(w_s0_a[31:0]);
                OP_FMT_I32     : w_s0_a_ir = int32_to_ir(w_s0_a);
                OP_FMT_I64     : w_s0_a_ir = int64_to_ir(w_s0_a);
                default        : w_s0_a_ir = '0;
            endcase
            unique case (w_s0_b_opd_fmt)
                OP_FMT_FP32    : w_s0_b_ir = fp32_to_ir(w_s0_b[31:0]);
                OP_FMT_FP16    : w_s0_b_ir = fp16_to_ir(w_s0_b[31:0]);
                OP_FMT_FP8_E4M3: w_s0_b_ir = fp8_to_ir(w_s0_b[31:0]);
                OP_FMT_BF16    : w_s0_b_ir = bf16_to_ir(w_s0_b[31:0]);
                OP_FMT_FP8_E5M2: w_s0_b_ir = fp8_e5m2_to_ir(w_s0_b[31:0]);
                OP_FMT_I32     : w_s0_b_ir = int32_to_ir(w_s0_b);
                OP_FMT_I64     : w_s0_b_ir = int64_to_ir(w_s0_b);
                default        : w_s0_b_ir = '0;
            endcase
            unique case (w_s0_c_opd_fmt)
                OP_FMT_FP32    : w_s0_c_ir = fp32_to_ir(w_s0_c[31:0]);
                OP_FMT_FP16    : w_s0_c_ir = fp16_to_ir(w_s0_c[31:0]);
                OP_FMT_FP8_E4M3: w_s0_c_ir = fp8_to_ir(w_s0_c[31:0]);
                OP_FMT_BF16    : w_s0_c_ir = bf16_to_ir(w_s0_c[31:0]);
                OP_FMT_FP8_E5M2: w_s0_c_ir = fp8_e5m2_to_ir(w_s0_c[31:0]);
                OP_FMT_I32     : w_s0_c_ir = int32_to_ir(w_s0_c);
                OP_FMT_I64     : w_s0_c_ir = int64_to_ir(w_s0_c);
                default        : w_s0_c_ir = '0;
            endcase

            if (w_s0_fp_op == FNMA || w_s0_fp_op == FNMS) begin
                w_s0_a_ir.sgn = ~w_s0_a_ir.sgn;
            end

            if (w_s0_fp_op == ADD || w_s0_fp_op == SUB) begin
                if (w_s0_fp_op == SUB) begin
                    w_s0_c_ir.sgn = ~w_s0_c_ir.sgn;
                end

                w_s0_b_ir = fp32_to_ir(32'h3f80_0000);

            end else if (w_s0_fp_op == MUL) begin
                w_s0_c_ir = '0;

            end else if (w_s0_fp_op == FMS || w_s0_fp_op == FNMS) begin
                w_s0_c_ir.sgn = ~w_s0_c_ir.sgn;
            end
        end: cvt2ir
        
        assign w_s0_lzc_a = lzc(w_s0_a_ir.intg);

        always_ff @(posedge w_lane_clk) begin: s0_pr_s1
            if (!w_lane_rst_n) begin
                w_s1_a          <= '0;
                w_s1_b          <= '0;
                w_s1_c          <= '0;
                w_s1_valid      <= 1'b0;
                w_s1_thrd       <= '0;
                w_s1_fp_op      <= ILGL;
                w_s1_a_opd_fmt  <= OP_FMT_ILGL;
                w_s1_b_opd_fmt  <= OP_FMT_ILGL;
                w_s1_c_opd_fmt  <= OP_FMT_ILGL;
                w_s1_result_fmt <= FMT_ILGL;
                w_s1_lzc_a      <= '0;
            end else if (w_s0_valid) begin
                w_s1_a          <= w_s0_a_ir;
                w_s1_b          <= w_s0_b_ir;
                w_s1_c          <= w_s0_c_ir;
                w_s1_valid      <= w_s0_valid;
                w_s1_thrd       <= w_s0_thrd;
                w_s1_fp_op      <= w_s0_fp_op;
                w_s1_a_opd_fmt  <= w_s0_a_opd_fmt;
                w_s1_b_opd_fmt  <= w_s0_b_opd_fmt;
                w_s1_c_opd_fmt  <= w_s0_c_opd_fmt;
                w_s1_result_fmt <= w_s0_result_fmt;
                w_s1_lzc_a      <= w_s0_lzc_a;
            end else begin
                w_s1_valid      <= 1'b0;
            end
        end: s0_pr_s1

        /* 
         * s1---
         * p0s1: PPG & c alignment
         * p1s1: sign based invert/select & flags
         * p2s1: noop
         */
        opd_fmt_e               w_s2_a_opd_fmt;
        opd_fmt_e               w_s2_b_opd_fmt;
        opd_fmt_e               w_s2_c_opd_fmt;
        fp_format_e             w_s2_result_fmt;
        fp_ir_t                 w_s2_a;
        fp_ir_t                 w_s2_b;
        fp_op_e                 w_s2_fp_op;
        logic                   w_s2_valid;
        logic [XLEN-1:0]        w_s2_thrd;
        fp_ir_t                 w_s2_c_aligned;
        logic [IR_MAN_W*2-1:0]  w_s2_pp_sum;
        logic [IR_MAN_W*2-1:0]  w_s2_pp_carry;
        logic                   w_s2_cmp_gt;
        logic                   w_s2_cmp_eq;
        logic                   w_s2_cmp_lt;
        logic                   w_s2_cmp_unordered;
        logic [LCZ_W-1:0]       w_s2_lzc_a;
        

        fp_ir_t                 w_s1_c_aligned;
        logic [IR_MAN_W*2-1:0]  w_s1_pp_sum;
        logic [IR_MAN_W*2-1:0]  w_s1_pp_carry;
        logic                   w_s1_cmp_gt;
        logic                   w_s1_cmp_eq;
        logic                   w_s1_cmp_lt;
        logic                   w_s1_cmp_unordered;


        always_comb begin: align_c
            {w_s1_pp_sum, w_s1_pp_carry} 
                           = booth_ppg(w_s1_a, w_s1_b);
            w_s1_c_aligned = align_shift_c(w_s1_c, w_s1_a, w_s1_b);
        end: align_c

        always_comb begin: cmp0
            {w_s1_cmp_gt, w_s1_cmp_eq, w_s1_cmp_lt, w_s1_cmp_unordered} 
                           = field_compare(w_s1_a, w_s1_b);
        end: cmp0

        
        always_ff @(posedge w_lane_clk) begin: s1_pr_s2
            if (!w_lane_rst_n) begin
                w_s2_a             <= '0;
                w_s2_b             <= '0;
                w_s2_c_aligned     <= '0;
                w_s2_valid         <= 1'b0;
                w_s2_thrd          <= '0;
                w_s2_fp_op         <= ILGL;
                w_s2_a_opd_fmt     <= OP_FMT_ILGL;
                w_s2_b_opd_fmt     <= OP_FMT_ILGL;
                w_s2_c_opd_fmt     <= OP_FMT_ILGL;
                w_s2_result_fmt    <= FMT_ILGL;
                w_s2_pp_sum        <= '0;
                w_s2_pp_carry      <= '0;
                w_s2_cmp_gt        <= 1'b0;
                w_s2_cmp_eq        <= 1'b0;
                w_s2_cmp_lt        <= 1'b0;
                w_s2_cmp_unordered <= 1'b0;
                w_s2_lzc_a         <= '0;
            end else if (w_s1_valid) begin
                w_s2_a             <= w_s1_a;
                w_s2_b             <= w_s1_b;
                w_s2_c_aligned     <= w_s1_c_aligned;
                w_s2_valid         <= w_s1_valid;
                w_s2_thrd          <= w_s1_thrd;
                w_s2_fp_op         <= w_s1_fp_op;
                w_s2_a_opd_fmt     <= w_s1_a_opd_fmt;
                w_s2_b_opd_fmt     <= w_s1_b_opd_fmt;
                w_s2_c_opd_fmt     <= w_s1_c_opd_fmt;
                w_s2_result_fmt    <= w_s1_result_fmt;
                w_s2_pp_sum        <= w_s1_pp_sum;
                w_s2_pp_carry      <= w_s1_pp_carry;
                w_s2_cmp_gt        <= w_s1_cmp_gt;
                w_s2_cmp_eq        <= w_s1_cmp_eq;
                w_s2_cmp_lt        <= w_s1_cmp_lt;
                w_s2_cmp_unordered <= w_s1_cmp_unordered;
                w_s2_lzc_a         <= w_s1_lzc_a;
            end else begin
                w_s2_valid         <= 1'b0;
            end
        end: s1_pr_s2


        /*
         * s2---
         * p0s2: CSA0 & inject aligned c
         * p1s2: invalid/exception flags
         * p2s2: noop
         */
        opd_fmt_e               w_s3_a_opd_fmt;
        opd_fmt_e               w_s3_b_opd_fmt;
        opd_fmt_e               w_s3_c_opd_fmt;
        fp_format_e             w_s3_result_fmt;
        fp_op_e                 w_s3_fp_op;
        logic                   w_s3_valid;
        logic [XLEN-1:0]        w_s3_thrd;
        fp_ir_t                 w_s3_c_aligned;
        logic [IR_MAN_W*2-1:0]  w_s3_csa0_sum;
        logic [IR_MAN_W*2-1:0]  w_s3_csa0_carry;
        logic                   w_s3_fma_sgn;
        logic                   w_s3_cmp_result;
        flags_t                 w_s3_cmp_flags;
        fp_ir_t                 w_s3_a;
        fp_ir_t                 w_s3_b;
        logic                   w_s3_cvt_ovf_clamp;
        logic [SHMT_W-1:0]      w_s3_cvt_shamt;


        logic [IR_MAN_W*2-1:0]  w_s2_csa0_sum;
        logic [IR_MAN_W*2-1:0]  w_s2_csa0_carry;
        logic                   w_s2_fma_sgn;
        logic                   w_s2_cmp_result;
        flags_t                 w_s2_cmp_flags;
        logic                   w_s2_cvt_ovf_clamp;
        logic [SHMT_W-1:0]      w_s2_cvt_shamt;

        
        always_comb begin: csa0
            {w_s2_fma_sgn, w_s2_csa0_sum, w_s2_csa0_carry}
                = csa_inject(w_s2_pp_sum, w_s2_pp_carry, w_s2_c_aligned,
                             w_s2_a, w_s2_b);
        end: csa0

        always_comb begin: cmp1
            {w_s2_cmp_result, w_s2_cmp_flags}
                = cmp_select(w_s2_fp_op, w_s2_a, w_s2_b, w_s2_cmp_gt, 
                             w_s2_cmp_eq, w_s2_cmp_lt, w_s2_cmp_unordered);
        end: cmp1

        always_comb begin: cvt
            {w_s2_cvt_ovf_clamp, w_s2_cvt_shamt}
                = cvt_clamp_decide(w_s2_fp_op, w_s2_a, w_s2_lzc_a);
        end: cvt


        always_ff @(posedge w_lane_clk) begin: s2_pr_s3
            if (!w_lane_rst_n) begin
                w_s3_a_opd_fmt      <= OP_FMT_ILGL;
                w_s3_b_opd_fmt      <= OP_FMT_ILGL;
                w_s3_c_opd_fmt      <= OP_FMT_ILGL;
                w_s3_result_fmt     <= FMT_ILGL;
                w_s3_fp_op          <= ILGL;
                w_s3_c_aligned      <= '0;
                w_s3_csa0_sum       <= '0;
                w_s3_csa0_carry     <= '0;
                w_s3_fma_sgn        <= 1'b0;
                w_s3_cmp_result     <= '0;
                w_s3_cmp_flags      <= FLG_OK;
                w_s3_cvt_ovf_clamp  <= 1'b0;
                w_s3_cvt_shamt      <= '0;
                w_s3_a              <= '0;
                w_s3_b              <= '0;
                w_s3_valid          <= 1'b0;
                w_s3_thrd           <= '0;
            end else if (w_s2_valid) begin
                w_s3_a_opd_fmt      <= w_s2_a_opd_fmt;
                w_s3_b_opd_fmt      <= w_s2_b_opd_fmt;
                w_s3_c_opd_fmt      <= w_s2_c_opd_fmt;
                w_s3_result_fmt     <= w_s2_result_fmt;
                w_s3_fp_op          <= w_s2_fp_op;
                w_s3_c_aligned      <= w_s2_c_aligned;
                w_s3_csa0_sum       <= w_s2_csa0_sum;
                w_s3_csa0_carry     <= w_s2_csa0_carry;
                w_s3_fma_sgn        <= w_s2_fma_sgn;
                w_s3_cmp_result     <= w_s2_cmp_result;
                w_s3_cmp_flags      <= w_s2_cmp_flags;
                w_s3_cvt_ovf_clamp  <= w_s2_cvt_ovf_clamp;
                w_s3_cvt_shamt      <= w_s2_cvt_shamt;
                w_s3_a              <= w_s2_a;
                w_s3_b              <= w_s2_b;
                w_s3_valid          <= w_s2_valid;
                w_s3_thrd           <= w_s2_thrd;
            end else begin
                w_s3_valid          <= 1'b0;
            end
        end: s2_pr_s3

        /* 
         * s3---
         * p0s3:CSA1 & lza start & GRS
         * p1s3:noop
         * p2s3:overflow/saturate clamp decision
         */
        opd_fmt_e               w_s4_a_opd_fmt;
        opd_fmt_e               w_s4_b_opd_fmt;
        opd_fmt_e               w_s4_c_opd_fmt;
        fp_format_e             w_s4_result_fmt;
        fp_op_e                 w_s4_fp_op;
        logic                   w_s4_valid;
        logic [XLEN-1:0]        w_s4_thrd;
        logic [IR_MAN_W*2-1:0]  w_s4_csa1_sum;
        logic [IR_MAN_W*2-1:0]  w_s4_csa1_carry;
        logic                   w_s4_fma_sgn;
        logic [LCZ_W-1:0]       w_s4_lza_shmt;
        logic [GRS_W-1:0]       w_s4_grs;
        logic                   w_s4_cmp_result;
        flags_t                 w_s4_cmp_flags;
        fp_ir_t                 w_s4_a;
        fp_ir_t                 w_s4_b;
        fp_ir_t                 w_s4_c_aligned;
        logic                   w_s4_cvt_ovf_clamp;
        logic [SHMT_W-1:0]      w_s4_cvt_shamt;


        logic [IR_MAN_W*2-1:0]  w_s3_csa1_sum;
        logic [IR_MAN_W*2-1:0]  w_s3_csa1_carry;
        logic [LCZ_W-1:0]       w_s3_lza_shmt;
        logic [GRS_W-1:0]       w_s3_grs;
        flags_t                 w_s3_cmp_flags_;

        
        always_comb begin: csa1_lza_grs
            {w_s3_csa1_sum, w_s3_csa1_carry} 
                          = csa_reduce_final(w_s3_csa0_sum, w_s3_csa0_carry);
            w_s3_lza_shmt = lza_predict(w_s3_csa1_sum, w_s3_csa1_carry);
            w_s3_grs      = grs_extract_speculative(
                            w_s3_csa1_sum, w_s3_csa1_carry, w_s3_lza_shmt);
        end: csa1_lza_grs

        always_comb begin: latch_cmp_flags
            w_s3_cmp_flags_ = cmp_flag_latch(w_s3_cmp_flags);
        end: latch_cmp_flags

        always_ff @(posedge w_lane_clk) begin: s3_pr_s4
            if (!w_lane_rst_n) begin
                w_s4_a_opd_fmt      <= OP_FMT_ILGL;
                w_s4_b_opd_fmt      <= OP_FMT_ILGL;
                w_s4_c_opd_fmt      <= OP_FMT_ILGL;
                w_s4_result_fmt     <= FMT_ILGL;
                w_s4_fp_op          <= ILGL;
                w_s4_csa1_sum       <= '0;
                w_s4_csa1_carry     <= '0;
                w_s4_fma_sgn        <= 1'b0;
                w_s4_lza_shmt       <= '0;
                w_s4_grs            <= '0;
                w_s4_cmp_result     <= '0;
                w_s4_cmp_flags      <= FLG_OK;
                w_s4_cvt_ovf_clamp  <= 1'b0;
                w_s4_cvt_shamt      <= '0;
                w_s4_a              <= '0;
                w_s4_b              <= '0;
                w_s4_c_aligned      <= '0;
                w_s4_valid          <= 1'b0;
                w_s4_thrd           <= '0;
            end else if (w_s3_valid) begin
                w_s4_a_opd_fmt      <= w_s3_a_opd_fmt;
                w_s4_b_opd_fmt      <= w_s3_b_opd_fmt;
                w_s4_c_opd_fmt      <= w_s3_c_opd_fmt;
                w_s4_result_fmt     <= w_s3_result_fmt;
                w_s4_fp_op          <= w_s3_fp_op;
                w_s4_csa1_sum       <= w_s3_csa1_sum;
                w_s4_csa1_carry     <= w_s3_csa1_carry;
                w_s4_fma_sgn        <= w_s3_fma_sgn;
                w_s4_lza_shmt       <= w_s3_lza_shmt;
                w_s4_grs            <= w_s3_grs;
                w_s4_cmp_result     <= w_s3_cmp_result;
                w_s4_cmp_flags      <= w_s3_cmp_flags_;
                w_s4_cvt_ovf_clamp  <= w_s3_cvt_ovf_clamp;
                w_s4_cvt_shamt      <= w_s3_cvt_shamt;
                w_s4_a              <= w_s3_a;
                w_s4_b              <= w_s3_b;
                w_s4_c_aligned      <= w_s3_c_aligned;
                w_s4_valid          <= w_s3_valid;
                w_s4_thrd           <= w_s3_thrd;
            end else begin
                w_s4_valid          <= 1'b0;
            end
        end: s3_pr_s4


        /*
         * s4---
         * p0s4:CPA & normalize
         * p1s4:noop
         * p2s4:normalize int or align/denormalize
         */
        opd_fmt_e                   w_s5_a_opd_fmt;
        opd_fmt_e                   w_s5_b_opd_fmt;
        opd_fmt_e                   w_s5_c_opd_fmt;
        fp_format_e                 w_s5_result_fmt;
        fp_op_e                     w_s5_fp_op;
        logic                       w_s5_valid;
        logic [XLEN-1:0]            w_s5_thrd;
        logic [IR_MAN_W-1:0]        w_s5_man_norm;
        logic signed [IR_EXP_W-1:0] w_s5_exp_norm;
        logic                       w_s5_sgn_norm;
        logic [GRS_W-1:0]           w_s5_grs;
        logic                       w_s5_cmp_result;
        flags_t                     w_s5_cmp_flags;
        logic [IR_MAN_W-1:0]        w_s5_man_shifted;
        logic signed [IR_EXP_W-1:0] w_s5_exp_shifted;
        logic                       w_s5_sgn_shifted;
        logic                       w_s5_cvt_ovf_clamp;
        fp_ir_t                     w_s5_a;
        fp_ir_t                     w_s5_b;
        fp_ir_t                     w_s5_c;


        logic [GRS_W-1:0]           w_s4_grs_final;
        logic [GRS_W-1:0]           w_s4_grs_;
        logic [IR_MAN_W*2-1:0]      w_s4_resolved;
        logic [IR_MAN_W-1:0]        w_s4_man_shifted;
        logic [IR_MAN_W-1:0]        w_s4_man_norm;
        logic signed [IR_EXP_W-1:0] w_s4_exp_shifted;
        logic signed [IR_EXP_W-1:0] w_s4_exp_norm;
        logic                       w_s4_sgn_shifted;
        logic                       w_s4_sgn_norm;
        logic [IR_MAN_W-1:0]        w_s4_man;
        logic                       w_s4_is_cvt;

        always_comb begin: cpa
            w_s4_resolved = cpa_add(w_s4_csa1_sum, w_s4_csa1_carry);
        end: cpa

        always_comb begin: norm
            w_s4_is_cvt           = (w_s4_fp_op == CVTF2F
                                  || w_s4_fp_op == CVTF2I
                                  || w_s4_fp_op == CVTI2F);
            {w_s4_man, w_s4_grs_} = barrel_shift(
                                w_s4_is_cvt
                                  ? {{(IR_MAN_W*2-XLEN){1'b0}}, w_s4_a.intg}
                                  : w_s4_resolved,
                                w_s4_is_cvt
                                  ? w_s4_cvt_shamt
                                  : w_s4_lza_shmt, !w_s4_is_cvt);
            w_s4_man_shifted      = w_s4_man;
            w_s4_man_norm         = w_s4_man;
            w_s4_exp_shifted      = w_s4_a.exp;
            w_s4_exp_norm         = w_s4_c_aligned.exp
                                  + 1 - IR_EXP_W'(w_s4_lza_shmt);
            w_s4_sgn_shifted      = w_s4_a.sgn;
            w_s4_sgn_norm         = w_s4_fma_sgn;
            w_s4_grs_final        = w_s4_grs_ | w_s4_grs;
        end: norm

        always_ff @(posedge w_lane_clk) begin: s4_pr_s5
            if (!w_lane_rst_n) begin
                w_s5_a_opd_fmt      <= OP_FMT_ILGL;
                w_s5_b_opd_fmt      <= OP_FMT_ILGL;
                w_s5_c_opd_fmt      <= OP_FMT_ILGL;
                w_s5_result_fmt     <= FMT_ILGL;
                w_s5_fp_op          <= ILGL;
                w_s5_man_norm       <= '0;
                w_s5_exp_norm       <= '0;
                w_s5_sgn_norm       <= 1'b0;
                w_s5_grs            <= '0;
                w_s5_cmp_result     <= 1'b0;
                w_s5_cmp_flags      <= FLG_OK;
                w_s5_man_shifted    <= '0;
                w_s5_exp_shifted    <= '0;
                w_s5_sgn_shifted    <= 1'b0;
                w_s5_cvt_ovf_clamp  <= 1'b0;
                w_s5_a              <= '0;
                w_s5_b              <= '0;
                w_s5_c              <= '0;
                w_s5_valid          <= 1'b0;
                w_s5_thrd           <= '0;
            end else if (w_s4_valid) begin
                w_s5_a_opd_fmt      <= w_s4_a_opd_fmt;
                w_s5_b_opd_fmt      <= w_s4_b_opd_fmt;
                w_s5_c_opd_fmt      <= w_s4_c_opd_fmt;
                w_s5_result_fmt     <= w_s4_result_fmt;
                w_s5_fp_op          <= w_s4_fp_op;
                w_s5_man_norm       <= w_s4_man_norm;
                w_s5_exp_norm       <= w_s4_exp_norm;
                w_s5_sgn_norm       <= w_s4_sgn_norm;
                w_s5_grs            <= w_s4_grs_final;
                w_s5_cmp_result     <= w_s4_cmp_result;
                w_s5_cmp_flags      <= w_s4_cmp_flags;
                w_s5_man_shifted    <= w_s4_man_shifted;
                w_s5_exp_shifted    <= w_s4_exp_shifted;
                w_s5_sgn_shifted    <= w_s4_sgn_shifted;
                w_s5_cvt_ovf_clamp  <= w_s4_cvt_ovf_clamp;
                w_s5_a              <= w_s4_a;
                w_s5_b              <= w_s4_b;
                w_s5_c              <= w_s4_c_aligned;
                w_s5_valid          <= w_s4_valid;
                w_s5_thrd           <= w_s4_thrd;
            end else begin
                w_s5_valid          <= 1'b0;
            end
        end: s4_pr_s5


        /*
         * s5---
         * p0s5:Round & unpack
         * p1s5:noop
         * p2s5:Round & unpack
         */
        fp_op_e                     w_s6_fp_op;
        logic [XLEN-1:0]            w_s6_thrd;
        logic [XLEN-1:0]            w_s6_result;
        flags_t                     w_s6_flags;
        logic                       w_s6_valid;


        logic [XLEN-1:0]            w_s5_result;
        flags_t                     w_s5_flags;


        always_comb begin: round
            automatic logic            is_cvt;
            automatic logic            is_cmp;
            automatic logic            is_max;
            automatic logic            is_min;
            automatic fp_bits_t        rounded_result;
            automatic flags_t          rounded_flags;
            automatic special_result_t special_result;

            is_cvt      = (w_s5_fp_op == CVTF2F
                        || w_s5_fp_op == CVTF2I
                        || w_s5_fp_op == CVTI2F);
            is_cmp      = w_s5_fp_op == CMP;
            is_max      = w_s5_fp_op == MAX;
            is_min      = w_s5_fp_op == MIN;
            special_result
                        = arithmetic_special_case( w_s5_fp_op, w_s5_a, w_s5_b, w_s5_c,
                        w_s5_result_fmt);
            {rounded_result, rounded_flags}
                        = round_pack(
                    is_cvt
                        ? w_s5_man_shifted
                        : w_s5_man_norm,
                    is_cvt
                        ? w_s5_exp_shifted
                        : w_s5_exp_norm,
                    is_cvt
                        ? w_s5_sgn_shifted
                        : w_s5_sgn_norm, w_s5_grs, w_s5_result_fmt);
            w_s5_result = {{(XLEN-32){1'b0}}, rounded_result};
            w_s5_flags  = rounded_flags;

            w_s5_result = is_cmp
                        ? {{(XLEN-1){1'b0}}, w_s5_cmp_result}
                        : w_s5_result;
            w_s5_flags  = is_cmp ? w_s5_cmp_flags : w_s5_flags;
            w_s5_result = is_max
                        ? {{(XLEN-32){1'b0}},
                           ir2fp(w_s5_cmp_result ? w_s5_a : w_s5_b,
                                 w_s5_result_fmt)}
                        : w_s5_result;
            w_s5_result = is_min
                        ? {{(XLEN-32){1'b0}},
                           ir2fp(w_s5_cmp_result ? w_s5_b : w_s5_a,
                                 w_s5_result_fmt)}
                        : w_s5_result;
            w_s5_result = (w_s5_fp_op == CVTF2F)
                        ? {{(XLEN-32){1'b0}},
                           ir2fp(w_s5_a, w_s5_result_fmt)}
                        : w_s5_result;
            w_s5_result = (w_s5_fp_op == CVTF2I)
                        ? fp32_to_int64(w_s5_a) : w_s5_result;
            w_s5_result = (w_s5_fp_op == CVTI2F)
                        ? {{(XLEN-32){1'b0}},
                           int64_to_fp(w_s5_a.intg, w_s5_result_fmt)}
                        : w_s5_result;
            w_s5_result = special_result[32]
                        ? {{(XLEN-32){1'b0}}, special_result[31:0]}
                        : w_s5_result;
        end: round

        always_ff @(posedge w_lane_clk) begin: s5_pr_s6
            if (!w_lane_rst_n) begin
                w_s6_fp_op          <= ILGL;
                w_s6_result         <= '0;
                w_s6_flags          <= FLG_OK;
                w_s6_valid          <= 1'b0;
                w_s6_thrd           <= '0;
            end else if (w_s5_valid) begin
                w_s6_fp_op          <= w_s5_fp_op;
                w_s6_result         <= w_s5_result;
                w_s6_flags          <= w_s5_flags;
                w_s6_valid          <= w_s5_valid;
                w_s6_thrd           <= w_s5_thrd;
            end else begin
                w_s6_valid          <= 1'b0;
            end
        end: s5_pr_s6
    end: lane




    /* mux_demux---  */

    logic                   w_clk;
    logic                   w_rst_n;
    logic                   w_l0_in_valid;
    logic                   w_l0_in_ready;
    fp_op_e                 w_l0_op;
    opd_fmt_e               w_l0_a_fmt;
    opd_fmt_e               w_l0_b_fmt;
    opd_fmt_e               w_l0_c_fmt;
    fp_format_e             w_l0_result_fmt;
    logic [XLEN-1:0]        w_l0_in_thrd;
    logic [XLEN-1:0]        w_l0_a;
    logic [XLEN-1:0]        w_l0_b;
    logic [XLEN-1:0]        w_l0_c;
    logic                   w_l0_out_ready;
    logic                   w_l0_out_valid;
    logic [XLEN-1:0]        w_l0_out_thrd;
    logic [XLEN-1:0]        w_l0_result;
    logic                   w_l1_in_valid;
    logic                   w_l1_in_ready;
    fp_op_e                 w_l1_op;
    opd_fmt_e               w_l1_a_fmt;
    opd_fmt_e               w_l1_b_fmt;
    opd_fmt_e               w_l1_c_fmt;
    fp_format_e             w_l1_result_fmt;
    logic [XLEN-1:0]        w_l1_in_thrd;
    logic [XLEN-1:0]        w_l1_a;
    logic [XLEN-1:0]        w_l1_b;
    logic [XLEN-1:0]        w_l1_c;
    logic                   w_l1_out_ready;
    logic                   w_l1_out_valid;
    logic [XLEN-1:0]        w_l1_out_thrd;
    logic [XLEN-1:0]        w_l1_result;


    logic                   w_is_iter_own_p0;
    logic                   w_is_iter_own_p1;
    logic                   w_p0_in_valid;
    fp_op_e                 w_p0_op;
    opd_fmt_e               w_p0_a_fmt;
    opd_fmt_e               w_p0_b_fmt;
    opd_fmt_e               w_p0_c_fmt;
    fp_format_e             w_p0_result_fmt;
    logic [XLEN-1:0]        w_p0_thrd;
    logic [XLEN-1:0]        w_p0_a;
    logic [XLEN-1:0]        w_p0_b;
    logic [XLEN-1:0]        w_p0_c;
    logic                   w_iter_p0_in_valid;
    fp_op_e                 w_iter_p0_op;
    opd_fmt_e               w_iter_p0_a_fmt;
    opd_fmt_e               w_iter_p0_b_fmt;
    opd_fmt_e               w_iter_p0_c_fmt;
    fp_format_e             w_iter_p0_result_fmt;
    logic [XLEN-1:0]        w_iter_p0_thrd;
    logic [XLEN-1:0]        w_iter_p0_a;
    logic [XLEN-1:0]        w_iter_p0_b;
    logic [XLEN-1:0]        w_iter_p0_c;
    logic                   w_p0_out_valid;
    logic [XLEN-1:0]        w_p0_out_thrd;
    logic [XLEN-1:0]        w_p0_result;
    logic                   w_p1_in_valid;
    fp_op_e                 w_p1_op;
    opd_fmt_e               w_p1_a_fmt;
    opd_fmt_e               w_p1_b_fmt;
    opd_fmt_e               w_p1_c_fmt;
    fp_format_e             w_p1_result_fmt;
    logic [XLEN-1:0]        w_p1_thrd;
    logic [XLEN-1:0]        w_p1_a;
    logic [XLEN-1:0]        w_p1_b;
    logic [XLEN-1:0]        w_p1_c;
    logic                   w_iter_p1_in_valid;
    fp_op_e                 w_iter_p1_op;
    opd_fmt_e               w_iter_p1_a_fmt;
    opd_fmt_e               w_iter_p1_b_fmt;
    opd_fmt_e               w_iter_p1_c_fmt;
    fp_format_e             w_iter_p1_result_fmt;
    logic [XLEN-1:0]        w_iter_p1_thrd;
    logic [XLEN-1:0]        w_iter_p1_a;
    logic [XLEN-1:0]        w_iter_p1_b;
    logic [XLEN-1:0]        w_iter_p1_c;
    logic                   w_p1_out_valid;
    logic [XLEN-1:0]        w_p1_out_thrd;
    logic [XLEN-1:0]        w_p1_result;

    assign w_clk             = i_clk;
    assign w_rst_n           = i_rst_n;
    assign w_l0_in_valid     = i_l0_in_valid;
    assign w_l0_op           = i_l0_op;
    assign w_l0_a_fmt        = i_l0_a_fmt;
    assign w_l0_b_fmt        = i_l0_b_fmt;
    assign w_l0_c_fmt        = i_l0_c_fmt;
    assign w_l0_result_fmt   = i_l0_result_fmt;
    assign w_l0_in_thrd      = i_l0_thrd;
    assign w_l0_a            = i_l0_a;
    assign w_l0_b            = i_l0_b;
    assign w_l0_c            = i_l0_c;
    assign w_l0_out_ready    = i_l0_out_ready;
    assign w_l1_in_valid     = i_l1_in_valid;
    assign w_l1_op           = i_l1_op;
    assign w_l1_a_fmt        = i_l1_a_fmt;
    assign w_l1_b_fmt        = i_l1_b_fmt;
    assign w_l1_c_fmt        = i_l1_c_fmt;
    assign w_l1_result_fmt   = i_l1_result_fmt;
    assign w_l1_in_thrd      = i_l1_thrd;
    assign w_l1_a            = i_l1_a;
    assign w_l1_b            = i_l1_b;
    assign w_l1_c            = i_l1_c;
    assign w_l1_out_ready    = i_l1_out_ready;
    assign o_l0_in_ready     = w_l0_in_ready;
    assign o_l0_out_valid    = w_l0_out_valid;
    assign o_l0_thrd         = w_l0_out_thrd;
    assign o_l0_result       = w_l0_result;
    assign o_l1_in_ready     = w_l1_in_ready;
    assign o_l1_out_valid    = w_l1_out_valid;
    assign o_l1_thrd         = w_l1_out_thrd;
    assign o_l1_result       = w_l1_result;
    assign w_p0_out_valid    = lane[0].w_s6_valid;
    assign w_p0_out_thrd     = lane[0].w_s6_thrd;
    assign w_p0_result       = lane[0].w_s6_result;
    assign w_p1_out_valid    = lane[1].w_s6_valid;
    assign w_p1_out_thrd     = lane[1].w_s6_thrd;
    assign w_p1_result       = lane[1].w_s6_result;

    always_comb begin: pipe_mux
        w_p0_in_valid             = w_l0_in_valid && w_l0_op != DIV && w_l0_op != SQRT;
        w_p0_op                   = w_l0_op;
        w_p0_a_fmt                = w_l0_a_fmt;
        w_p0_b_fmt                = w_l0_b_fmt;
        w_p0_c_fmt                = w_l0_c_fmt;
        w_p0_result_fmt           = w_l0_result_fmt;
        w_p0_thrd                 = w_l0_in_thrd;
        w_p0_a                    = w_l0_a;
        w_p0_b                    = w_l0_b;
        w_p0_c                    = w_l0_c;
        w_p1_in_valid             = w_l1_in_valid;
        w_p1_op                   = w_l1_op;
        w_p1_a_fmt                = w_l1_a_fmt;
        w_p1_b_fmt                = w_l1_b_fmt;
        w_p1_c_fmt                = w_l1_c_fmt;
        w_p1_result_fmt           = w_l1_result_fmt;
        w_p1_thrd                 = w_l1_in_thrd;
        w_p1_a                    = w_l1_a;
        w_p1_b                    = w_l1_b;
        w_p1_c                    = w_l1_c;

        lane[0].w_lane_clk        = w_clk;
        lane[0].w_lane_rst_n      = w_rst_n;
        lane[0].w_s0_valid        = w_p0_in_valid;
        lane[0].w_s0_fp_op        = w_p0_op;
        lane[0].w_s0_a_opd_fmt    = w_p0_a_fmt;
        lane[0].w_s0_b_opd_fmt    = w_p0_b_fmt;
        lane[0].w_s0_c_opd_fmt    = w_p0_c_fmt;
        lane[0].w_s0_result_fmt   = w_p0_result_fmt;
        lane[0].w_s0_thrd         = w_p0_thrd;
        lane[0].w_s0_a            = w_p0_a;
        lane[0].w_s0_b            = w_p0_b;
        lane[0].w_s0_c            = w_p0_c;
        lane[1].w_lane_clk        = w_clk;
        lane[1].w_lane_rst_n      = w_rst_n;
        lane[1].w_s0_valid        = w_p1_in_valid;
        lane[1].w_s0_fp_op        = w_p1_op;
        lane[1].w_s0_a_opd_fmt    = w_p1_a_fmt;
        lane[1].w_s0_b_opd_fmt    = w_p1_b_fmt;
        lane[1].w_s0_c_opd_fmt    = w_p1_c_fmt;
        lane[1].w_s0_result_fmt   = w_p1_result_fmt;
        lane[1].w_s0_thrd         = w_p1_thrd;
        lane[1].w_s0_a            = w_p1_a;
        lane[1].w_s0_b            = w_p1_b;
        lane[1].w_s0_c            = w_p1_c;

        if (w_is_iter_own_p0) begin
            lane[0].w_s0_valid      = w_iter_p0_in_valid;
            lane[0].w_s0_fp_op      = w_iter_p0_op;
            lane[0].w_s0_a_opd_fmt  = w_iter_p0_a_fmt;
            lane[0].w_s0_b_opd_fmt  = w_iter_p0_b_fmt;
            lane[0].w_s0_c_opd_fmt  = w_iter_p0_c_fmt;
            lane[0].w_s0_result_fmt = w_iter_p0_result_fmt;
            lane[0].w_s0_thrd       = w_iter_p0_thrd;
            lane[0].w_s0_a          = w_iter_p0_a;
            lane[0].w_s0_b          = w_iter_p0_b;
            lane[0].w_s0_c          = w_iter_p0_c;
        end

        if (w_is_iter_own_p1) begin
            lane[1].w_s0_valid      = w_iter_p1_in_valid;
            lane[1].w_s0_fp_op      = w_iter_p1_op;
            lane[1].w_s0_a_opd_fmt  = w_iter_p1_a_fmt;
            lane[1].w_s0_b_opd_fmt  = w_iter_p1_b_fmt;
            lane[1].w_s0_c_opd_fmt  = w_iter_p1_c_fmt;
            lane[1].w_s0_result_fmt = w_iter_p1_result_fmt;
            lane[1].w_s0_thrd       = w_iter_p1_thrd;
            lane[1].w_s0_a          = w_iter_p1_a;
            lane[1].w_s0_b          = w_iter_p1_b;
            lane[1].w_s0_c          = w_iter_p1_c;
        end

    end: pipe_mux

    fp_iter fp_iter (
        .i_clk              (w_clk),
        .i_rst_n            (w_rst_n),
        .i_l0_in_valid      (w_l0_in_valid),
        .o_l0_in_ready      (w_l0_in_ready),
        .i_l0_op            (w_l0_op),
        .i_l0_a_fmt         (w_l0_a_fmt),
        .i_l0_b_fmt         (w_l0_b_fmt),
        .i_l0_c_fmt         (w_l0_c_fmt),
        .i_l0_result_fmt    (w_l0_result_fmt),
        .i_l0_thrd          (w_l0_in_thrd),
        .i_l0_a             (w_l0_a),
        .i_l0_b             (w_l0_b),
        .i_l0_c             (w_l0_c),
        .i_l0_out_ready     (w_l0_out_ready),
        .o_l0_out_valid     (w_l0_out_valid),
        .o_l0_thrd          (w_l0_out_thrd),
        .o_l0_result        (w_l0_result),
        .i_l1_in_valid      (w_l1_in_valid),
        .o_l1_in_ready      (w_l1_in_ready),
        .i_l1_op            (w_l1_op),
        .i_l1_a_fmt         (w_l1_a_fmt),
        .i_l1_b_fmt         (w_l1_b_fmt),
        .i_l1_c_fmt         (w_l1_c_fmt),
        .i_l1_result_fmt    (w_l1_result_fmt),
        .i_l1_thrd          (w_l1_in_thrd),
        .i_l1_a             (w_l1_a),
        .i_l1_b             (w_l1_b),
        .i_l1_c             (w_l1_c),
        .i_l1_out_ready     (w_l1_out_ready),
        .o_l1_out_valid     (w_l1_out_valid),
        .o_l1_thrd          (w_l1_out_thrd),
        .o_l1_result        (w_l1_result),
        .o_is_iter_own_p0   (w_is_iter_own_p0),
        .o_is_iter_own_p1   (w_is_iter_own_p1),
        .o_p0_in_valid      (w_iter_p0_in_valid),
        .o_p0_op            (w_iter_p0_op),
        .o_p0_a_fmt         (w_iter_p0_a_fmt),
        .o_p0_b_fmt         (w_iter_p0_b_fmt),
        .o_p0_c_fmt         (w_iter_p0_c_fmt),
        .o_p0_result_fmt    (w_iter_p0_result_fmt),
        .o_p0_thrd          (w_iter_p0_thrd),
        .o_p0_a             (w_iter_p0_a),
        .o_p0_b             (w_iter_p0_b),
        .o_p0_c             (w_iter_p0_c),
        .i_p0_out_valid     (w_p0_out_valid),
        .i_p0_thrd          (w_p0_out_thrd),
        .i_p0_result        (w_p0_result),
        .o_p1_in_valid      (w_iter_p1_in_valid),
        .o_p1_op            (w_iter_p1_op),
        .o_p1_a_fmt         (w_iter_p1_a_fmt),
        .o_p1_b_fmt         (w_iter_p1_b_fmt),
        .o_p1_c_fmt         (w_iter_p1_c_fmt),
        .o_p1_result_fmt    (w_iter_p1_result_fmt),
        .o_p1_thrd          (w_iter_p1_thrd),
        .o_p1_a             (w_iter_p1_a),
        .o_p1_b             (w_iter_p1_b),
        .o_p1_c             (w_iter_p1_c),
        .i_p1_out_valid     (w_p1_out_valid),
        .i_p1_thrd          (w_p1_out_thrd),
        .i_p1_result        (w_p1_result)
    );
    /* mux_demux---  */

endmodule: fpu_datapath

`default_nettype wire
