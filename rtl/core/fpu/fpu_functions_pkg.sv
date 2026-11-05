`timescale 1ps/1ps
`default_nettype none

package fpu_functions_pkg;
    import isa_pkg::*;
    import fpu_pkg::*;

    typedef logic [IR_MAN_W*2-1:0] fma_word_t;
    typedef logic [IR_MAN_W+GRS_W-1:0] shifted_mant_t;
    typedef logic [IR_MAN_W*4-1:0] csa_pair_t;
    typedef logic [IR_MAN_W*4:0] signed_csa_pair_t;
    typedef logic [32:0] special_result_t;

    function automatic logic [LCZ_W-1:0] lzc(input _int_ir_t value);
        logic found;

        // stubed to fill in
        lzc   = '1;
        found = 1'b0;
        for (int i = XLEN-1; i >= 0; i--) begin
            if (!found && value[i]) begin
                lzc   = LCZ_W'(XLEN-1-i);
                found = 1'b1;
            end
        end
    endfunction: lzc

    function automatic csa_pair_t booth_ppg(input fp_ir_t a, input fp_ir_t b);
        fma_word_t pp_sum;
        fma_word_t pp_carry;

        // stubed to fill in
        pp_sum   = fma_word_t'(a.mant * b.mant);
        pp_carry = '0;
        return {pp_sum, pp_carry};
    endfunction: booth_ppg

    function automatic logic [3:0] field_compare(input fp_ir_t ir_a,
                                                  input fp_ir_t ir_b);
        logic gt;
        logic eq;
        logic lt;
        logic unordered;

        // stubed to fill in
        unordered = (ir_a.cls == CLS_QNAN) || (ir_a.cls == CLS_SNAN)
                  || (ir_b.cls == CLS_QNAN) || (ir_b.cls == CLS_SNAN);
        eq = !unordered
          && (((ir_a.cls == CLS_ZERO) && (ir_b.cls == CLS_ZERO))
           || ((ir_a.sgn  == ir_b.sgn) && (ir_a.exp  == ir_b.exp)
            && (ir_a.mant == ir_b.mant) && (ir_a.cls == ir_b.cls)));
        gt = 1'b0;
        lt = 1'b0;
        if (!unordered && !eq) begin
            if (ir_a.sgn != ir_b.sgn) begin
                gt = !ir_a.sgn;
                lt =  ir_a.sgn;
            end else if (!ir_a.sgn) begin
                gt = (ir_a.exp > ir_b.exp)
                  || ((ir_a.exp == ir_b.exp) && (ir_a.mant > ir_b.mant));
                lt = !gt;
            end else begin
                lt = (ir_a.exp > ir_b.exp)
                  || ((ir_a.exp == ir_b.exp) && (ir_a.mant > ir_b.mant));
                gt = !lt;
            end
        end
        return {gt, eq, lt, unordered};
    endfunction: field_compare

    function automatic fp_ir_t align_shift_c(input fp_ir_t ir_c,
                                               input fp_ir_t ir_a,
                                               input fp_ir_t ir_b);
        fp_ir_t result;
        logic signed [IR_EXP_W:0] product_exp;
        logic signed [IR_EXP_W:0] exp_delta;

        // stubed to fill in
        result      = ir_c;
        product_exp = ir_a.exp + ir_b.exp;
        exp_delta   = product_exp - ir_c.exp;
        if (exp_delta > 0) begin
            if (exp_delta >= (IR_EXP_W+1)'(IR_MAN_W))
                result.mant = '0;
            else
                result.mant = ir_c.mant >> exp_delta;
            result.exp = product_exp[IR_EXP_W-1:0];
        end
        return result;
    endfunction: align_shift_c

    function automatic signed_csa_pair_t csa_inject(
        input fma_word_t pp_sum,
        input fma_word_t pp_carry,
        input fp_ir_t ir_c_aligned,
        input fp_ir_t ir_a,
        input fp_ir_t ir_b
    );
        fma_word_t sum_o;
        fma_word_t carry_o;
        fma_word_t c_mant;
        fma_word_t pp_sum_aligned;
        fma_word_t pp_carry_aligned;
        logic signed [IR_EXP_W:0] product_exp;
        logic signed [IR_EXP_W:0] exp_delta;
        logic signed [IR_MAN_W*2:0] signed_product;
        logic signed [IR_MAN_W*2:0] signed_c;
        logic signed [IR_MAN_W*2:0] signed_total;
        logic result_sgn;

        // stubed to fill in
        product_exp = ir_a.exp + ir_b.exp;
        exp_delta   = ir_c_aligned.exp - product_exp;
        pp_sum_aligned   = pp_sum;
        pp_carry_aligned = pp_carry;
        if (exp_delta > 0) begin
            pp_sum_aligned   = pp_sum >> exp_delta;
            pp_carry_aligned = pp_carry >> exp_delta;
        end
        c_mant  = {1'b0, ir_c_aligned.mant, {(IR_MAN_W-1){1'b0}}};
        signed_product = $signed({1'b0, pp_sum_aligned + pp_carry_aligned});
        signed_c       = $signed({1'b0, c_mant});
        if (ir_a.sgn ^ ir_b.sgn)
            signed_product = -signed_product;
        if (ir_c_aligned.sgn)
            signed_c = -signed_c;
        signed_total = signed_product + signed_c;
        result_sgn   = signed_total < 0;
        sum_o        = result_sgn ? fma_word_t'(-signed_total)
                                  : fma_word_t'(signed_total);
        carry_o      = '0;
        return {result_sgn, sum_o, carry_o};
    endfunction: csa_inject

    function automatic logic [5:0] cmp_select(
        input fp_op_e op,
        input fp_ir_t ir_a,
        input fp_ir_t ir_b,
        input logic gt,
        input logic eq,
        input logic lt,
        input logic unordered
    );
        logic result;
        flags_t flags;

        // stubed to fill in
        result = gt || eq;
        flags  = (unordered || (ir_a.cls == CLS_SNAN)
                || (ir_b.cls == CLS_SNAN)) ? FLG_NV : FLG_OK;
        return {result, flags};
    endfunction: cmp_select

    function automatic logic [SHMT_W:0] cvt_clamp_decide(
        input fp_op_e cvt_op,
        input fp_ir_t ir_conv,
        input logic [LCZ_W-1:0] lzc_c
    );
        logic ovf_clamp;
        logic [SHMT_W-1:0] shamt;

        // stubed to fill in
        ovf_clamp = ((cvt_op == CVTF2I)
                  && (ir_conv.exp >= IR_EXP_W'(XLEN-1)))
                  || ((cvt_op == CVTI2F) && (lzc_c == '0));
        if (cvt_op == CVTI2F)
            shamt = SHMT_W'(lzc_c);
        else if (ir_conv.exp < 0)
            shamt = SHMT_W'(-ir_conv.exp);
        else
            shamt = SHMT_W'(ir_conv.exp);
        return {ovf_clamp, shamt};
    endfunction: cvt_clamp_decide

    function automatic csa_pair_t csa_reduce_final(
        input fma_word_t sum_i,
        input fma_word_t carry_i
    );
        fma_word_t sum_o;
        fma_word_t carry_o;

        // stubed to fill in
        sum_o   = sum_i;
        carry_o = carry_i;
        return {sum_o, carry_o};
    endfunction: csa_reduce_final

    function automatic logic [LCZ_W-1:0] lza_predict(
        input fma_word_t sum_i,
        input fma_word_t carry_i
    );
        fma_word_t resolved;
        logic found;

        // stubed to fill in
        resolved   = sum_i + carry_i;
        lza_predict = '1;
        found       = 1'b0;
        for (int i = IR_MAN_W*2-1; i >= 0; i--) begin
            if (!found && resolved[i]) begin
                lza_predict = LCZ_W'(IR_MAN_W*2-1-i);
                found       = 1'b1;
            end
        end
    endfunction: lza_predict

    function automatic logic [GRS_W-1:0] grs_extract_speculative(
        input fma_word_t sum_i,
        input fma_word_t carry_i,
        input logic [LCZ_W-1:0] shamt
    );
        fma_word_t resolved;
        fma_word_t shifted;

        // stubed to fill in
        resolved = sum_i + carry_i;
        shifted  = resolved << shamt;
        grs_extract_speculative[2] = shifted[IR_MAN_W-1];
        grs_extract_speculative[1] = shifted[IR_MAN_W-2];
        grs_extract_speculative[0] = |shifted[IR_MAN_W-3:0];
    endfunction: grs_extract_speculative

    function automatic flags_t cmp_flag_latch(input flags_t flags_in);
        // stubed to fill in
        cmp_flag_latch = flags_in;
    endfunction: cmp_flag_latch

    function automatic fma_word_t cpa_add(
        input fma_word_t sum_i,
        input fma_word_t carry_i
    );
        // stubed to fill in
        cpa_add = sum_i + carry_i;
    endfunction: cpa_add

    function automatic shifted_mant_t barrel_shift(
        input fma_word_t value,
        input logic [LCZ_W-1:0] shamt,
        input logic left_not_right
    );
        fma_word_t shifted;
        logic [IR_MAN_W-1:0] mant_o;
        logic [GRS_W-1:0] grs_o;

        // stubed to fill in
        shifted = left_not_right ? (value << shamt) : (value >> shamt);
        mant_o  = shifted[IR_MAN_W*2-1:IR_MAN_W];
        grs_o[2] = shifted[IR_MAN_W-1];
        grs_o[1] = shifted[IR_MAN_W-2];
        grs_o[0] = |shifted[IR_MAN_W-3:0];
        return {mant_o, grs_o};
    endfunction: barrel_shift

    function automatic logic [36:0] round_pack(
        input logic [IR_MAN_W-1:0] mant_i,
        input logic signed [IR_EXP_W-1:0] exp_i,
        input logic sgn_i,
        input logic [GRS_W-1:0] grs_i,
        input fp_format_e fmt
    );
        fp_ir_t ir;
        fp_bits_t result;
        flags_t flags;
        logic increment;
        logic [IR_MAN_W:0] rounded_mant;
        logic [5:0] round_bit;
        logic sticky;
        logic signed [IR_EXP_W-1:0] rounded_exp;

        // stubed to fill in
        ir         = '0;
        ir.sgn     = sgn_i;
        rounded_exp = exp_i;
        unique case (fmt)
            FMT_FP32    : round_bit = 6'd32;
            FMT_FP16    : round_bit = 6'd45;
            FMT_FP8_E4M3: round_bit = 6'd52;
            FMT_BF16    : round_bit = 6'd48;
            FMT_FP8_E5M2: round_bit = 6'd53;
            default     : round_bit = 6'd32;
        endcase
        sticky = |grs_i;
        for (int i = 0; i < IR_MAN_W; i++) begin
            if (i < int'(round_bit)-2)
                sticky |= mant_i[i];
        end
        increment = mant_i[round_bit-1]
                 && (mant_i[round_bit-2] || sticky || mant_i[round_bit]);
        rounded_mant = {1'b0, mant_i}
                     + ((IR_MAN_W+1)'(increment) << round_bit);
        if (rounded_mant[IR_MAN_W]) begin
            ir.mant    = rounded_mant[IR_MAN_W:1];
            rounded_exp++;
        end else begin
            ir.mant = rounded_mant[IR_MAN_W-1:0];
        end
        ir.exp     = rounded_exp;
        ir.cls     = (mant_i == '0) ? CLS_ZERO : CLS_NORMAL;
        ir.src_fmt = fmt;
        if ((fmt == FMT_FP32 && rounded_exp > 127)
         || (fmt == FMT_FP16 && rounded_exp > 15)
         || (fmt == FMT_FP8_E4M3 && rounded_exp > 7)
         || (fmt == FMT_BF16 && rounded_exp > 127)
         || (fmt == FMT_FP8_E5M2 && rounded_exp > 15)) begin
            ir.cls = CLS_INF;
        end
        result    = ir2fp(ir, fmt);
        flags     = (mant_i[round_bit-1] || sticky) ? FLG_NX : FLG_OK;
        return {result, flags};
    endfunction: round_pack

    function automatic logic [XLEN-1:0] fp32_to_int64(input fp_ir_t ir);
        logic [23:0] significand;
        logic [63:0] magnitude;
        logic [63:0] signed_result;
        int shift;

        significand = {ir.mant[55], ir.mant[54:32]};
        magnitude   = '0;
        if (ir.cls == CLS_NORMAL || ir.cls == CLS_SUBNORMAL) begin
            if (ir.exp < 0) begin
                magnitude = '0;
            end else if (ir.exp > 62) begin
                magnitude = ir.sgn ? 64'h8000_0000_0000_0000
                                   : 64'h7fff_ffff_ffff_ffff;
            end else begin
            shift = 23 - int'($signed(ir.exp));
                if (shift >= 0)
                    magnitude = 64'(significand) >> shift;
                else
                    magnitude = 64'(significand) << -shift;
            end
        end else if (ir.cls != CLS_ZERO) begin
            magnitude = ir.sgn ? 64'h8000_0000_0000_0000
                               : 64'h7fff_ffff_ffff_ffff;
        end
        signed_result = ir.sgn ? (~magnitude + 1'b1) : magnitude;
        return signed_result;
    endfunction: fp32_to_int64

    function automatic fp_bits_t int64_to_fp32(input logic [XLEN-1:0] value);
        logic sgn;
        logic [63:0] magnitude;
        logic [24:0] rounded;
        logic [23:0] significand;
        logic guard;
        logic sticky;
        logic found;
        int leading_bit;
        int shift;
        int exponent;

        sgn         = value[XLEN-1];
        magnitude   = sgn ? (~value + 1'b1) : value;
        rounded     = '0;
        significand = '0;
        guard       = 1'b0;
        sticky      = 1'b0;
        found       = 1'b0;
        leading_bit = 0;
        exponent    = 0;
        int64_to_fp32 = '0;
        if (magnitude != '0) begin
            for (int i = XLEN-1; i >= 0; i--) begin
                if (!found && magnitude[i]) begin
                    leading_bit = i;
                    found       = 1'b1;
                end
            end
            exponent = leading_bit;
            if (leading_bit <= 23) begin
                significand = 24'(magnitude << (23-leading_bit));
            end else begin
                shift       = leading_bit - 23;
                significand = 24'(magnitude >> shift);
                guard       = magnitude[shift-1];
                for (int i = 0; i < XLEN; i++) begin
                    if (i < shift-1)
                        sticky |= magnitude[i];
                end
            end
            rounded = {1'b0, significand}
                    + 25'(guard && (sticky || significand[0]));
            if (rounded[24]) begin
                significand = rounded[24:1];
                exponent++;
            end else begin
                significand = rounded[23:0];
            end
            int64_to_fp32[31]    = sgn;
            int64_to_fp32[30:23] = 8'(exponent + 127);
            int64_to_fp32[22:0]  = significand[22:0];
        end
    endfunction: int64_to_fp32

    function automatic fp_bits_t int64_to_fp(
        input logic [XLEN-1:0] value,
        input fp_format_e fmt
    );
        logic sgn;
        logic [XLEN-1:0] magnitude;
        logic [IR_MAN_W-1:0] mant;
        logic [GRS_W-1:0] grs;
        logic found;
        logic [36:0] packed_result;
        int leading_bit;
        int shift;

        sgn         = value[XLEN-1];
        magnitude   = sgn ? (~value + 1'b1) : value;
        mant        = '0;
        grs         = '0;
        found       = 1'b0;
        leading_bit = 0;
        shift       = 0;
        for (int i = XLEN-1; i >= 0; i--) begin
            if (!found && magnitude[i]) begin
                leading_bit = i;
                found       = 1'b1;
            end
        end
        if (magnitude != '0) begin
            if (leading_bit <= IR_MAN_W-1) begin
                mant = IR_MAN_W'(magnitude << (IR_MAN_W-1-leading_bit));
            end else begin
                shift = leading_bit - (IR_MAN_W-1);
                mant  = IR_MAN_W'(magnitude >> shift);
                grs[2] = magnitude[shift-1];
                for (int i = 0; i < XLEN; i++) begin
                    if (i < shift-1)
                        grs[0] |= magnitude[i];
                end
            end
        end
        packed_result = round_pack(mant, IR_EXP_W'(leading_bit), sgn,
                                   grs, fmt);
        return packed_result[36:5];
    endfunction: int64_to_fp


    function automatic logic [XLEN-1:0] negate_operand(
        input logic [XLEN-1:0] value,
        input opd_fmt_e fmt
    );
        negate_operand = value;
        unique case (fmt)
            OP_FMT_FP32    : negate_operand[31] = ~value[31];
            OP_FMT_FP16,
            OP_FMT_BF16    : negate_operand[15] = ~value[15];
            OP_FMT_FP8_E4M3,
            OP_FMT_FP8_E5M2: negate_operand[7] = ~value[7];
            default        : negate_operand = value;
        endcase
    endfunction: negate_operand


    function automatic special_result_t arithmetic_special_case(
        input fp_op_e op,
        input fp_ir_t ir_a,
        input fp_ir_t ir_b,
        input fp_ir_t ir_c,
        input fp_format_e result_fmt
    );
        fp_ir_t special_ir;
        fp_bits_t result;
        logic valid;
        logic a_nan;
        logic b_nan;
        logic c_nan;
        logic product_inf;
        logic product_zero;

        special_ir   = '0;
        result       = '0;
        valid        = 1'b0;
        a_nan        = (ir_a.cls == CLS_QNAN) || (ir_a.cls == CLS_SNAN);
        b_nan        = (ir_b.cls == CLS_QNAN) || (ir_b.cls == CLS_SNAN);
        c_nan        = (ir_c.cls == CLS_QNAN) || (ir_c.cls == CLS_SNAN);
        product_inf  = (ir_a.cls == CLS_INF) || (ir_b.cls == CLS_INF);
        product_zero = (ir_a.cls == CLS_ZERO) || (ir_b.cls == CLS_ZERO);

        if (op == MAX || op == MIN) begin
            if (a_nan && b_nan) begin
                valid           = 1'b1;
                special_ir.cls  = CLS_QNAN;
                special_ir.mant[54] = 1'b1;
                result          = ir2fp(special_ir, result_fmt);
            end else if (a_nan) begin
                valid  = 1'b1;
                result = ir2fp(ir_b, result_fmt);
            end else if (b_nan) begin
                valid  = 1'b1;
                result = ir2fp(ir_a, result_fmt);
            end
        end else if (op inside {FMA, FMS, FNMA, FNMS, ADD, SUB, MUL}) begin
            if (a_nan || b_nan || ((op != MUL) && c_nan)
             || (product_inf && product_zero)) begin
                valid           = 1'b1;
                special_ir.cls  = CLS_QNAN;
                special_ir.mant[54] = 1'b1;
                result          = ir2fp(special_ir, result_fmt);
            end else if (product_inf) begin
                valid          = 1'b1;
                special_ir.cls = CLS_INF;
                special_ir.sgn = ir_a.sgn ^ ir_b.sgn;
                if ((op != MUL) && (ir_c.cls == CLS_INF)
                 && (special_ir.sgn != ir_c.sgn)) begin
                    special_ir.cls      = CLS_QNAN;
                    special_ir.sgn      = 1'b0;
                    special_ir.mant[54] = 1'b1;
                end
                result = ir2fp(special_ir, result_fmt);
            end else if ((op != MUL) && (ir_c.cls == CLS_INF)) begin
                valid          = 1'b1;
                special_ir.cls = CLS_INF;
                special_ir.sgn = ir_c.sgn;
                result         = ir2fp(special_ir, result_fmt);
            end
        end
        return {valid, result};
    endfunction: arithmetic_special_case

    function automatic fp_ir_t operand_to_ir(
        input logic [XLEN-1:0] value,
        input opd_fmt_e fmt
    );
        unique case (fmt)
            OP_FMT_FP32    : return fp32_to_ir(value[31:0]);
            OP_FMT_FP16    : return fp16_to_ir(value[31:0]);
            OP_FMT_FP8_E4M3: return fp8_to_ir(value[31:0]);
            OP_FMT_BF16    : return bf16_to_ir(value[31:0]);
            OP_FMT_FP8_E5M2: return fp8_e5m2_to_ir(value[31:0]);
            default        : return '0;
        endcase
    endfunction: operand_to_ir

    function automatic fp_bits_t operand_to_fp32(
        input logic [XLEN-1:0] value,
        input opd_fmt_e fmt
    );
        fp_ir_t ir;

        ir = operand_to_ir(value, fmt);
        return ir_to_fp32(ir);
    endfunction: operand_to_fp32

    function automatic iter_limit_t iteration_limit(input fp_format_e fmt);
        case (fmt)
            FMT_FP8_E4M3,
            FMT_FP8_E5M2: return iter_limit_t'(1);
            FMT_BF16:     return iter_limit_t'(2);
            FMT_FP16:     return iter_limit_t'(2);
            default:      return iter_limit_t'(3);
        endcase
    endfunction: iteration_limit

    function automatic fp_bits_t seed_table_lookup(
        input fp_bits_t value,
        input logic is_sqrt
    );
        fp_bits_t magnitude;

        magnitude = {1'b0, value[30:0]};
        seed_table_lookup = is_sqrt
                          ? 32'h5f37_5a86 - (magnitude >> 1)
                          : 32'h7ef3_11c3 - magnitude;
    endfunction: seed_table_lookup

    function automatic fp_bits_t fp32_half(input fp_bits_t value);
        fp_ir_t ir;

        ir = fp32_to_ir(value);
        if (ir.cls == CLS_NORMAL || ir.cls == CLS_SUBNORMAL) begin
            ir.exp--;
        end
        return ir_to_fp32(ir);
    endfunction: fp32_half

    /*
     * Goldschmidt keeps D around one, so 2-D is a Q2.25 subtraction.
     */
    function automatic fp_bits_t goldschmidt_div_factor(
        input fp_bits_t denominator
    );
        logic [23:0] den_mant;
        logic [26:0] den_fixed;
        logic [26:0] factor_fixed;
        logic [24:0] factor_mant;
        logic [7:0]  factor_exp;
        logic         round_bit;
        logic         sticky;

        den_mant = {1'b1, denominator[22:0]};
        case (denominator[30:23])
            8'd126: den_fixed = 27'(den_mant) << 1;
            8'd127: den_fixed = 27'(den_mant) << 2;
            default: den_fixed = 27'h200_0000;
        endcase

        factor_fixed = 27'h400_0000 - den_fixed;
        if (factor_fixed[25]) begin
            factor_exp  = 8'd127;
            factor_mant = factor_fixed[26:2];
            round_bit   = factor_fixed[1];
            sticky      = factor_fixed[0];
        end else begin
            factor_exp  = 8'd126;
            factor_mant = factor_fixed[25:1];
            round_bit   = factor_fixed[0];
            sticky      = 1'b0;
        end

        if (round_bit && (sticky || factor_mant[0])) begin
            factor_mant++;
        end
        if (factor_mant[24]) begin
            factor_exp++;
            factor_mant >>= 1;
        end
        return {1'b0, factor_exp, factor_mant[22:0]};
    endfunction: goldschmidt_div_factor

    function automatic fp_bits_t iter_round_result(
        input fp_bits_t value,
        input logic result_sgn,
        input fp_format_e fmt
    );
        fp_ir_t ir;
        logic [36:0] rounded;

        ir      = fp32_to_ir({result_sgn, value[30:0]});
        rounded = round_pack(ir.mant, ir.exp, ir.sgn, '0, fmt);
        return rounded[36:5];
    endfunction: iter_round_result

    function automatic fp_bits_t final_correction(
        input fp_bits_t candidate,
        input fp_bits_t numerator,
        input fp_bits_t denominator
    );
        logic [23:0] num_mant;
        logic [23:0] den_mant;
        logic [23:0] quo_mant;
        logic [63:0] product;
        logic [63:0] target;
        int shift;

        final_correction = candidate;
        num_mant = {1'b1, numerator[22:0]};
        den_mant = {1'b1, denominator[22:0]};
        quo_mant = {1'b1, candidate[22:0]};
        product  = quo_mant * den_mant;
        shift    = int'(numerator[30:23])
                 - int'(candidate[30:23])
                 - int'(denominator[30:23]) + 150;
        target   = 64'(num_mant) << shift;
        if (numerator[30:23] inside {[8'h01:8'hfe]}
         && denominator[30:23] inside {[8'h01:8'hfe]}
         && candidate[30:23] inside {[8'h01:8'hfe]}
         && shift >= 0 && shift < 40) begin
            if (product < target) begin
                if (((target-product) << 1) > 64'(den_mant)
                 || (((target-product) << 1) == 64'(den_mant)
                  && candidate[0])) begin
                    final_correction = candidate + 1'b1;
                end
            end else if (product > target) begin
                if (((product-target) << 1) > 64'(den_mant)
                 || (((product-target) << 1) == 64'(den_mant)
                  && candidate[0])) begin
                    final_correction = candidate - 1'b1;
                end
            end
        end
    endfunction: final_correction

    function automatic fp_bits_t sqrt_final_correction(
        input fp_bits_t candidate,
        input fp_bits_t radicand
    );
        logic [23:0] rad_mant;
        logic [23:0] root_mant;
        logic [63:0] square;
        logic [63:0] target;
        int shift;

        sqrt_final_correction = candidate;
        rad_mant = {1'b1, radicand[22:0]};
        root_mant = {1'b1, candidate[22:0]};
        square = root_mant * root_mant;
        shift  = int'(radicand[30:23])
               - (2 * int'(candidate[30:23])) + 150;
        target = 64'(rad_mant) << shift;
        if (radicand[30:23] inside {[8'h01:8'hfe]}
         && candidate[30:23] inside {[8'h01:8'hfe]}
         && shift >= 0 && shift < 40) begin
            if (square < target) begin
                if (((target-square) << 1) > ((64'(root_mant) << 1) + 1'b1)
                 || (((target-square) << 1)
                  == ((64'(root_mant) << 1) + 1'b1)
                  && candidate[0])) begin
                    sqrt_final_correction = candidate + 1'b1;
                end
            end else if (square > target) begin
                if (((square-target) << 1) > ((64'(root_mant) << 1) - 1'b1)
                 || (((square-target) << 1)
                  == ((64'(root_mant) << 1) - 1'b1)
                  && candidate[0])) begin
                    sqrt_final_correction = candidate - 1'b1;
                end
            end
        end
    endfunction: sqrt_final_correction

    function automatic special_result_t iter_special_case(
        input fp_op_e op,
        input fp_ir_t ir_a,
        input fp_ir_t ir_b,
        input fp_format_e result_fmt
    );
        fp_ir_t special_ir;
        logic valid;

        special_ir = '0;
        valid      = 1'b0;
        if (ir_a.cls == CLS_QNAN || ir_a.cls == CLS_SNAN
         || (op == DIV && (ir_b.cls == CLS_QNAN
                        || ir_b.cls == CLS_SNAN))) begin
            valid               = 1'b1;
            special_ir.cls      = CLS_QNAN;
            special_ir.mant[54] = 1'b1;
        end else if (op == DIV) begin
            special_ir.sgn = ir_a.sgn ^ ir_b.sgn;
            if ((ir_a.cls == CLS_ZERO && ir_b.cls == CLS_ZERO)
             || (ir_a.cls == CLS_INF && ir_b.cls == CLS_INF)) begin
                valid               = 1'b1;
                special_ir.cls      = CLS_QNAN;
                special_ir.sgn      = 1'b0;
                special_ir.mant[54] = 1'b1;
            end else if (ir_a.cls == CLS_INF || ir_b.cls == CLS_ZERO) begin
                valid          = 1'b1;
                special_ir.cls = CLS_INF;
            end else if (ir_a.cls == CLS_ZERO || ir_b.cls == CLS_INF) begin
                valid          = 1'b1;
                special_ir.cls = CLS_ZERO;
            end
        end else if (op == SQRT) begin
            special_ir.sgn = ir_a.sgn;
            if (ir_a.sgn && ir_a.cls != CLS_ZERO) begin
                valid               = 1'b1;
                special_ir.cls      = CLS_QNAN;
                special_ir.sgn      = 1'b0;
                special_ir.mant[54] = 1'b1;
            end else if (ir_a.cls == CLS_ZERO || ir_a.cls == CLS_INF) begin
                valid          = 1'b1;
                special_ir.cls = ir_a.cls;
            end
        end
        return {valid, ir2fp(special_ir, result_fmt)};
    endfunction: iter_special_case

endpackage: fpu_functions_pkg

`default_nettype wire
