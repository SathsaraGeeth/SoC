package fpu_pkg;
    import isa_pkg::*;

    typedef enum logic[3:0] { 
        FMA    = 4'd0,
        FMS    = 4'd1,
        FNMA   = 4'd2,
        FNMS   = 4'd3,
        ADD    = 4'd4,
        SUB    = 4'd5,
        MUL    = 4'd6,
        DIV    = 4'd7,
        SQRT   = 4'd8,
        CVTF2I = 4'd9,
        CVTF2F = 4'd10,
        CVTI2F = 4'd11,
        MAX    = 4'd12,
        MIN    = 4'd13,
        CMP    = 4'd14,
        ILGL   = 4'd15
    } fp_op_e;

    parameter int ITER_MAX_ITERS = 4;

    typedef enum logic [4:0] {
        ITER_IDLE,
        ITER_DIV_INIT,
        ITER_DIV_INIT_SECOND,
        ITER_DIV_INIT_WAIT,
        ITER_DIV_UPDATE_SECOND,
        ITER_DIV_UPDATE_WAIT,
        ITER_SQ_MUL,
        ITER_SQ_MUL_WAIT,
        ITER_SQ_PRODUCT_WAIT,
        ITER_SQ_FACTOR_WAIT,
        ITER_SQ_UPDATE_SECOND,
        ITER_SQ_UPDATE_WAIT,
        ITER_DONE
    } iter_state_e;

    typedef logic [$clog2(ITER_MAX_ITERS)-1:0] iter_ctr_t;
    typedef logic [$clog2(ITER_MAX_ITERS+1)-1:0] iter_limit_t;

    typedef enum logic [3:0] {
        ITER_TAG_DIV_NUM,
        ITER_TAG_DIV_DEN,
        ITER_TAG_SQ_INIT,
        ITER_TAG_SQ_PRODUCT,
        ITER_TAG_SQ_FACTOR,
        ITER_TAG_SQ_ROOT,
        ITER_TAG_SQ_HALF
    } iter_tag_e;

    typedef enum logic [4:0] {
        FLG_OK = 5'b00000,
        FLG_NV = 5'b00001,
        FLG_DZ = 5'b00010,
        FLG_OF = 5'b00100,
        FLG_UF = 5'b01000,
        FLG_NX = 5'b10000
    } flags_t;

    parameter int IR_MAN_W = 56;
    parameter int IR_EXP_W = 12;
    typedef logic [31:0] fp_bits_t;

    typedef enum logic [2:0] {
        FMT_FP32     = 3'd0,
        FMT_FP16     = 3'd1,
        FMT_FP8_E4M3 = 3'd2,
        FMT_BF16     = 3'd3,
        FMT_FP8_E5M2 = 3'd4,
        FMT_UND0     = 3'd5,
        FMT_UND1     = 3'd6,
        FMT_ILGL     = 3'd7
    } fp_format_e;

    typedef struct packed {
        fp_op_e              op;
        fp_format_e          result_fmt;
        logic [XLEN-1:0]     thrd;
        logic                result_sgn;
    } iter_request_t;

    typedef enum logic [2:0] {
        OP_FMT_FP32     = 3'd0,
        OP_FMT_FP16     = 3'd1,
        OP_FMT_FP8_E4M3 = 3'd2,
        OP_FMT_I32      = 3'd3,
        OP_FMT_I64      = 3'd4,
        OP_FMT_BF16     = 3'd5,
        OP_FMT_FP8_E5M2 = 3'd6,
        OP_FMT_ILGL     = 3'd7
    } opd_fmt_e;

    typedef enum logic [2:0] {
        CLS_ZERO      = 3'b000,
        CLS_NORMAL    = 3'b001,
        CLS_SUBNORMAL = 3'b010,
        CLS_INF       = 3'b011,
        CLS_QNAN      = 3'b100,
        CLS_SNAN      = 3'b101
    } fp_class_e;

    /*
     * 56b enough to hold 48b product + 8b GRS margin
     * FP32 fraction: mant[54:32]
     * FP16 fraction: mant[54:45]
     * BF16 fraction: mant[54:48]
     * FP8 E4M3 fraction: mant[54:52]
     * FP8 E5M2 fraction: mant[54:53]
     */
    typedef struct packed {
        logic                           sgn;
        logic signed [IR_EXP_W-1:0]     exp;
        logic [IR_MAN_W-1:0]            mant;
        fp_class_e                      cls;
        fp_format_e                     src_fmt;
    } _fp_ir_t;

    typedef logic [XLEN-1:0] _int_ir_t;

    typedef struct packed {
        logic                           sgn;
        logic signed [IR_EXP_W-1:0]     exp;
        logic [IR_MAN_W-1:0]            mant;
        fp_class_e                      cls;
        fp_format_e                     src_fmt;
        _int_ir_t                       intg;
    } fp_ir_t;

    parameter int LCZ_W  = $clog2(XLEN);
    parameter int SHMT_W = $clog2(XLEN);
    parameter int GRS_W  = 3;
    function automatic fp_ir_t int32_to_ir(input logic [XLEN-1:0] value);
        fp_ir_t result;
        result      = '0;
        result.intg = {{(XLEN-32){value[31]}}, value[31:0]};
        return result;
    endfunction : int32_to_ir

    function automatic fp_ir_t int64_to_ir(input logic [XLEN-1:0] value);
        fp_ir_t result;
        result      = '0;
        result.intg = value;
        return result;
    endfunction : int64_to_ir

    function automatic fp_ir_t fp32_to_ir(input fp_bits_t fp);
        fp_ir_t result;

        begin
            result         = '0;
            result.src_fmt = FMT_FP32;
            result.sgn     = fp[31];

            if (fp[30:23] == 8'h00) begin
                result.exp = -12'sd126;

                if (fp[22:0] == 23'h0) begin
                    result.cls = CLS_ZERO;
                end
                else begin
                    result.cls         = CLS_SUBNORMAL;
                    result.mant[54:32] = fp[22:0];
                end
            end
            else if (fp[30:23] == 8'hff) begin
                result.exp         = '0;
                result.mant[54:32] = fp[22:0];

                if (fp[22:0] == 23'h0)
                    result.cls = CLS_INF;
                else if (fp[22])
                    result.cls = CLS_QNAN;
                else
                    result.cls = CLS_SNAN;
            end
            else begin
                result.cls         = CLS_NORMAL;
                result.exp         = $signed({4'b0, fp[30:23]}) - 12'sd127;
                result.mant[55]    = 1'b1;
                result.mant[54:32] = fp[22:0];
            end

            return result;
        end
    endfunction : fp32_to_ir


    function automatic fp_ir_t fp16_to_ir(input fp_bits_t fp);
        fp_ir_t result;

        begin
            result         = '0;
            result.src_fmt = FMT_FP16;
            result.sgn     = fp[15];

            if (fp[14:10] == 5'h00) begin
                result.exp = -12'sd14;

                if (fp[9:0] == 10'h0) begin
                    result.cls = CLS_ZERO;
                end
                else begin
                    result.cls         = CLS_SUBNORMAL;
                    result.mant[54:45] = fp[9:0];
                end
            end
            else if (fp[14:10] == 5'h1f) begin
                result.exp         = '0;
                result.mant[54:45] = fp[9:0];

                if (fp[9:0] == 10'h0) begin
                    result.cls = CLS_INF;
                end else if (fp[9]) begin
                    result.cls = CLS_QNAN;
                end else begin
                    result.cls = CLS_SNAN;
                end
            end
            else begin
                result.cls         = CLS_NORMAL;
                result.exp         = $signed({7'b0, fp[14:10]}) - 12'sd15;
                result.mant[55]    = 1'b1;
                result.mant[54:45] = fp[9:0];
            end

            return result;
        end
    endfunction : fp16_to_ir


    function automatic fp_ir_t bf16_to_ir(input fp_bits_t fp);
        fp_ir_t result;

        begin
            result         = '0;
            result.src_fmt = FMT_BF16;
            result.sgn     = fp[15];

            if (fp[14:7] == 8'h00) begin
                result.exp = -12'sd126;

                if (fp[6:0] == 7'h0) begin
                    result.cls = CLS_ZERO;
                end else begin
                    result.cls         = CLS_SUBNORMAL;
                    result.mant[54:48] = fp[6:0];
                end
            end else if (fp[14:7] == 8'hff) begin
                result.exp         = '0;
                result.mant[54:48] = fp[6:0];

                if (fp[6:0] == 7'h0) begin
                    result.cls = CLS_INF;
                end else if (fp[6]) begin
                    result.cls = CLS_QNAN;
                end else begin
                    result.cls = CLS_SNAN;
                end
            end else begin
                result.cls         = CLS_NORMAL;
                result.exp         = $signed({4'b0, fp[14:7]}) - 12'sd127;
                result.mant[55]    = 1'b1;
                result.mant[54:48] = fp[6:0];
            end

            return result;
        end
    endfunction : bf16_to_ir


    function automatic fp_ir_t fp8_e5m2_to_ir(input fp_bits_t fp);
        fp_ir_t result;

        begin
            result         = '0;
            result.src_fmt = FMT_FP8_E5M2;
            result.sgn     = fp[7];

            if (fp[6:2] == 5'h00) begin
                result.exp = -12'sd14;

                if (fp[1:0] == 2'b00) begin
                    result.cls = CLS_ZERO;
                end else begin
                    result.cls         = CLS_SUBNORMAL;
                    result.mant[54:53] = fp[1:0];
                end
            end else if (fp[6:2] == 5'h1f) begin
                result.exp         = '0;
                result.mant[54:53] = fp[1:0];

                if (fp[1:0] == 2'b00) begin
                    result.cls = CLS_INF;
                end else if (fp[1]) begin
                    result.cls = CLS_QNAN;
                end else begin
                    result.cls = CLS_SNAN;
                end
            end else begin
                result.cls         = CLS_NORMAL;
                result.exp         = $signed({7'b0, fp[6:2]}) - 12'sd15;
                result.mant[55]    = 1'b1;
                result.mant[54:53] = fp[1:0];
            end

            return result;
        end
    endfunction : fp8_e5m2_to_ir


    function automatic fp_ir_t fp8_to_ir(input fp_bits_t fp);
        fp_ir_t result;

        begin
            result         = '0;
            result.src_fmt = FMT_FP8_E4M3;
            result.sgn     = fp[7];

            if (fp[6:3] == 4'h0) begin
                result.exp = -12'sd6;

                if (fp[2:0] == 3'h0) begin
                    result.cls = CLS_ZERO;
                end
                else begin
                    result.cls         = CLS_SUBNORMAL;
                    result.mant[54:52] = fp[2:0];
                end
            end
            else if (fp[6:3] == 4'hf) begin
                result.exp         = '0;
                result.mant[54:52] = fp[2:0];

                if (fp[2:0] == 3'h0) begin
                    result.cls = CLS_INF;
                end else if (fp[2]) begin
                    result.cls = CLS_QNAN;
                end else begin
                    result.cls = CLS_SNAN;
                end
            end
            else begin
                result.cls         = CLS_NORMAL;
                result.exp         = $signed({8'b0, fp[6:3]}) - 12'sd7;
                result.mant[55]    = 1'b1;
                result.mant[54:52] = fp[2:0];
            end

            return result;
        end
    endfunction : fp8_to_ir


    function automatic fp_bits_t ir_to_fp32(input fp_ir_t ir);
        fp_bits_t result;

        begin
            result     = '0;
            result[31] = ir.sgn;

            case (ir.cls)
                CLS_ZERO: begin
                    result[30:0] = '0;
                end
                CLS_SUBNORMAL: begin
                    result[30:23] = 8'h00;
                    result[22:0]  = ir.mant[54:32];
                end
                CLS_NORMAL: begin
                    result[30:23] = 8'($unsigned(ir.exp + 12'sd127));
                    result[22:0] = ir.mant[54:32];
                end
                CLS_INF: begin
                    result[30:23] = 8'hff;
                    result[22:0]  = 23'h0;
                end
                CLS_QNAN: begin
                    result[30:23] = 8'hff;
                    result[22:0]  = ir.mant[54:32];
                    result[22]    = 1'b1;
                end
                CLS_SNAN: begin
                    result[30:23] = 8'hff;
                    result[22:0]  = ir.mant[54:32];
                    result[22]    = 1'b0;

                    if (result[21:0] == 22'h0) begin
                        result[0] = 1'b1;
                    end
                end
                default: begin
                    result = '0;
                end
            endcase

            return result;
        end
    endfunction : ir_to_fp32


    function automatic fp_bits_t ir_to_fp16(input fp_ir_t ir);
        fp_bits_t result;

        begin
            result     = '0;
            result[15] = ir.sgn;

            case (ir.cls)
                CLS_ZERO: begin
                    result[14:0] = '0;
                end
                CLS_SUBNORMAL: begin
                    result[14:10] = 5'h00;
                    result[9:0]   = ir.mant[54:45];
                end
                CLS_NORMAL: begin
                    result[14:10] = 5'($unsigned(ir.exp + 12'sd15));
                    result[9:0]   = ir.mant[54:45];
                end
                CLS_INF: begin
                    result[14:10] = 5'h1f;
                    result[9:0]   = 10'h0;
                end
                CLS_QNAN: begin
                    result[14:10] = 5'h1f;
                    result[9:0]   = ir.mant[54:45];
                    result[9]     = 1'b1;
                end
                CLS_SNAN: begin
                    result[14:10] = 5'h1f;
                    result[9:0]   = ir.mant[54:45];
                    result[9]     = 1'b0;
                    if (result[8:0] == 9'h0) begin
                        result[0] = 1'b1;
                    end
                end
                default: begin
                    result = '0;
                end
            endcase

            return result;
        end
    endfunction : ir_to_fp16


    function automatic fp_bits_t ir_to_bf16(input fp_ir_t ir);
        fp_bits_t result;

        begin
            result     = '0;
            result[15] = ir.sgn;

            case (ir.cls)
                CLS_ZERO: begin
                    result[14:0] = '0;
                end
                CLS_SUBNORMAL: begin
                    result[14:7] = 8'h00;
                    result[6:0]  = ir.mant[54:48];
                end
                CLS_NORMAL: begin
                    result[14:7] = 8'($unsigned(ir.exp + 12'sd127));
                    result[6:0]  = ir.mant[54:48];
                end
                CLS_INF: begin
                    result[14:7] = 8'hff;
                    result[6:0]  = 7'h0;
                end
                CLS_QNAN: begin
                    result[14:7] = 8'hff;
                    result[6:0]  = ir.mant[54:48];
                    result[6]    = 1'b1;
                end
                CLS_SNAN: begin
                    result[14:7] = 8'hff;
                    result[6:0]  = ir.mant[54:48];
                    result[6]    = 1'b0;
                    if (result[5:0] == 6'h0) begin
                        result[0] = 1'b1;
                    end
                end
                default: begin
                    result = '0;
                end
            endcase

            return result;
        end
    endfunction : ir_to_bf16


    function automatic fp_bits_t ir_to_fp8_e5m2(input fp_ir_t ir);
        fp_bits_t result;

        begin
            result    = '0;
            result[7] = ir.sgn;

            case (ir.cls)
                CLS_ZERO: begin
                    result[6:0] = '0;
                end
                CLS_SUBNORMAL: begin
                    result[6:2] = 5'h00;
                    result[1:0] = ir.mant[54:53];
                end
                CLS_NORMAL: begin
                    result[6:2] = 5'($unsigned(ir.exp + 12'sd15));
                    result[1:0] = ir.mant[54:53];
                end
                CLS_INF: begin
                    result[6:2] = 5'h1f;
                    result[1:0] = 2'b00;
                end
                CLS_QNAN: begin
                    result[6:2] = 5'h1f;
                    result[1:0] = ir.mant[54:53];
                    result[1]   = 1'b1;
                end
                CLS_SNAN: begin
                    result[6:2] = 5'h1f;
                    result[1:0] = ir.mant[54:53];
                    result[1]   = 1'b0;
                    if (result[0] == 1'b0) begin
                        result[0] = 1'b1;
                    end
                end
                default: begin
                    result = '0;
                end
            endcase

            return result;
        end
    endfunction : ir_to_fp8_e5m2


    function automatic fp_bits_t ir_to_fp8(input fp_ir_t ir);
        fp_bits_t result;

        begin
            result    = '0;
            result[7] = ir.sgn;

            case (ir.cls)
                CLS_ZERO: begin
                    result[6:0] = '0;
                end
                CLS_SUBNORMAL: begin
                    result[6:3] = 4'h0;
                    result[2:0] = ir.mant[54:52];
                end
                CLS_NORMAL: begin
                    result[6:3] = 4'($unsigned(ir.exp + 12'sd7));
                    result[2:0] = ir.mant[54:52];
                end
                CLS_INF: begin
                    result[6:3] = 4'hf;
                    result[2:0] = 3'h0;
                end
                CLS_QNAN: begin
                    result[6:3] = 4'hf;
                    result[2:0] = ir.mant[54:52];
                    result[2]   = 1'b1;
                end
                CLS_SNAN: begin
                    result[6:3] = 4'hf;
                    result[2:0] = ir.mant[54:52];
                    result[2]   = 1'b0;
                    if (result[1:0] == 2'b00) begin
                        result[0] = 1'b1;
                    end
                end
                default: begin
                    result = '0;
                end
            endcase

            return result;
        end
    endfunction : ir_to_fp8


    function automatic fp_ir_t fp2ir( input fp_bits_t fp, input fp_format_e fmt);
        begin
            case (fmt)
                FMT_FP32:     return fp32_to_ir(fp);
                FMT_FP16:     return fp16_to_ir(fp);
                FMT_FP8_E4M3: return fp8_to_ir(fp);
                FMT_BF16:     return bf16_to_ir(fp);
                FMT_FP8_E5M2: return fp8_e5m2_to_ir(fp);

                default: begin
                    fp_ir_t result;
                    result     = '0;
                    result.cls = CLS_QNAN;
                    return result;
                end
            endcase
        end
    endfunction : fp2ir

    function automatic fp_bits_t ir2fp(input fp_ir_t ir, input fp_format_e fmt);
        begin
            case (fmt)
                FMT_FP32:     return ir_to_fp32(ir);
                FMT_FP16:     return ir_to_fp16(ir);
                FMT_FP8_E4M3: return ir_to_fp8(ir);
                FMT_BF16:     return ir_to_bf16(ir);
                FMT_FP8_E5M2: return ir_to_fp8_e5m2(ir);
                default:      return '0;
            endcase
        end
    endfunction : ir2fp
endpackage : fpu_pkg
