/*
 * Comments:
 * 1. Combinational
 */

`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;
import isa_pkg::*;

module decoder (
    input  logic    [INST_W-1:0]        i_instr,
    output decoded_instr_t              o_decoded
);
    mnemonic_e           w_mnemonic;
    logic [OPCODE_W-1:0] w_opcode;
    logic [REG_BITS-1:0] w_rd, w_rs1, w_rs2, w_rs3;
    logic [FUNCT3_W-1:0] w_f3;
    logic [XLEN-1:0]     w_imm_i, w_imm_s, w_imm_b, w_imm_u, w_imm_j;

    assign w_opcode   = inst_opcode(i_instr);
    assign w_rd       = inst_rd(i_instr);
    assign w_f3       = inst_funct3(i_instr);
    assign w_rs1      = inst_rs1(i_instr);
    assign w_rs2      = inst_rs2(i_instr);
    assign w_rs3      = inst_rs3(i_instr);
    assign w_mnemonic = decode(i_instr);
    assign w_imm_i    = inst_imm_i(i_instr);
    assign w_imm_s    = inst_imm_s(i_instr);
    assign w_imm_b    = inst_imm_b(i_instr);
    assign w_imm_u    = inst_imm_u(i_instr);
    assign w_imm_j    = inst_imm_j(i_instr);

    always_comb begin
        // defaults
        o_decoded.raw         = i_instr;
        o_decoded.pc          = '0;
        o_decoded.is_branch   = 1'b0;
        o_decoded.is_jump     = 1'b0;
        o_decoded.is_jalr     = 1'b0;
        o_decoded.is_ecall    = 1'b0;
        o_decoded.is_sret     = 1'b0;
        o_decoded.is_mret     = 1'b0;
        o_decoded.is_wfi      = 1'b0;
        o_decoded.use_imm     = 1'b0;
        o_decoded.use_pc      = 1'b0;
        o_decoded.alu_word    = 1'b0;
        o_decoded.fu          = FU_ALU;
        o_decoded.rawhz_t     = RAWHZ_NONE;
        o_decoded.alu_op      = ALU_ADD;
        o_decoded.fpu_op      = FPU_FADD;
        o_decoded.ls_op       = LS_LOAD_I8;
        o_decoded.ls_wen      = 1'b0;
        o_decoded.ls_lq       = 1'b0;
        o_decoded.ls_sc       = 1'b0;
        o_decoded.rf_wen      = 1'b0;
        o_decoded.csr_wen     = 1'b0;
        o_decoded.funct3      = w_f3;
        o_decoded.ls_unsigned = 1'b0;
        o_decoded.rd          = w_rd;
        o_decoded.rs1         = w_rs1;
        o_decoded.rs2         = w_rs2;
        o_decoded.rs3         = w_rs3;
        o_decoded.imm         = '0;

        unique case (w_opcode)
            OP_LOAD: begin
                o_decoded.fu          = FU_LSU;
                o_decoded.rawhz_t     = RAWHZ_RS1;
                o_decoded.imm         = w_imm_i;
                o_decoded.use_imm     = 1'b1;
                o_decoded.rf_wen      = (w_rd != X0);
                unique case (w_mnemonic)
                    M_LOAD_I8:  o_decoded.ls_op = LS_LOAD_I8;
                    M_LOAD_I16: o_decoded.ls_op = LS_LOAD_I16;
                    M_LOAD_I32: o_decoded.ls_op = LS_LOAD_I32;
                    M_LOAD_I64: o_decoded.ls_op = LS_LOAD_I64;
                    M_LOAD_U8:  o_decoded.ls_op = LS_LOAD_U8;
                    M_LOAD_U16: o_decoded.ls_op = LS_LOAD_U16;
                    M_LOAD_U32: o_decoded.ls_op = LS_LOAD_U32;
                    default:    o_decoded.ls_op = LS_LOAD_I32;
                endcase
            end

            OP_FLOAD: begin
                o_decoded.fu          = FU_LSU;
                o_decoded.rawhz_t     = RAWHZ_RS1;
                o_decoded.imm         = w_imm_i;
                o_decoded.use_imm     = 1'b1;
                o_decoded.rf_wen      = (w_rd != X0);
                o_decoded.ls_op       = (w_mnemonic == M_LOAD_F16) ? LS_LOAD_F16 : LS_LOAD_BF16;
            end

            OP_STORE: begin
                o_decoded.fu          = FU_LSU;
                o_decoded.rawhz_t     = RAWHZ_RS1_RS2;
                o_decoded.imm         = w_imm_s;
                o_decoded.use_imm     = 1'b1;
                o_decoded.ls_wen      = 1'b1;
                unique case (w_mnemonic)
                    M_STORE_8:  o_decoded.ls_op = LS_STORE_8;
                    M_STORE_16: o_decoded.ls_op = LS_STORE_16;
                    M_STORE_32: o_decoded.ls_op = LS_STORE_32;
                    M_STORE_64: o_decoded.ls_op = LS_STORE_64;
                    default:    o_decoded.ls_op = LS_STORE_32;
                endcase
            end

            OP_FSTORE: begin
                o_decoded.fu          = FU_LSU;
                o_decoded.rawhz_t     = RAWHZ_RS1_RS2;
                o_decoded.imm         = w_imm_s;
                o_decoded.use_imm     = 1'b1;
                o_decoded.ls_wen      = 1'b1;
                o_decoded.ls_op       = (w_mnemonic == M_STORE_F16) ? LS_STORE_F16 : LS_STORE_BF16;
            end

            OP_FALU: begin
                o_decoded.fu      = FU_FPU;
                o_decoded.rf_wen  = (w_rd != X0);
                o_decoded.rawhz_t = RAWHZ_RS1_RS2;
                unique case (w_mnemonic)
                    M_ADD_F32:      o_decoded.fpu_op = FPU_FADD;
                    M_SUB_F32:      o_decoded.fpu_op = FPU_FSUB;
                    M_MUL_F32:      o_decoded.fpu_op = FPU_FMUL;
                    M_SQRT_F32: begin
                        o_decoded.fpu_op  = FPU_FSQRT;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    M_FMIN_F32:     o_decoded.fpu_op = FPU_FMIN;
                    M_FMAX_F32:     o_decoded.fpu_op = FPU_FMAX;
                    M_FEQ_F32:      o_decoded.fpu_op = FPU_FCMP_EQ;
                    M_FLT_F32:      o_decoded.fpu_op = FPU_FCMP_LT;
                    M_FLE_F32:      o_decoded.fpu_op = FPU_FCMP_LE;
                    M_FSGNJ_F32:    o_decoded.fpu_op = FPU_FSGNJ;
                    M_FSGNJN_F32:   o_decoded.fpu_op = FPU_FSGNJN;
                    M_FSGNJX_F32:   o_decoded.fpu_op = FPU_FSGNJX;
                    M_FCLASS_F32: begin
                        o_decoded.fpu_op  = FPU_FCLASS;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    M_FCVT_F32_I64: begin
                        o_decoded.fpu_op  = FPU_CVT_I2F;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    M_FCVT_F32_I32: begin
                        o_decoded.fpu_op  = FPU_CVT_I2F;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    M_FCVT_I32_F32: begin
                        o_decoded.fpu_op  = FPU_CVT_F2I;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    M_FCVT_I64_F32: begin
                        o_decoded.fpu_op  = FPU_CVT_F2I;
                        o_decoded.rawhz_t = RAWHZ_RS1;
                    end
                    default: ;
                endcase
            end

            OP_FMADD,
            OP_FMSUB: begin
                o_decoded.fu      = FU_FPU;
                o_decoded.rf_wen  = (w_rd != X0);
                o_decoded.rawhz_t = RAWHZ_RS1_RS2_RS3;
                unique case (w_mnemonic)
                    M_FMADD_F32:  o_decoded.fpu_op = FPU_FMADD;
                    M_FMSUB_F32:  o_decoded.fpu_op = FPU_FMSUB;
                    M_FNMADD_F32: o_decoded.fpu_op = FPU_FNMADD;
                    M_FNMSUB_F32: o_decoded.fpu_op = FPU_FNMSUB;
                    default: ;
                endcase
            end

            OP_AMO: begin
                o_decoded.fu          = FU_LSU;
                o_decoded.rf_wen      = (w_rd != X0);
                unique case (w_mnemonic)
                    M_LOAD_I32_RES,
                    M_LOAD_I32_RES_AQ: begin
                        o_decoded.rawhz_t = RAWHZ_RS1;
                        o_decoded.ls_lq   = 1'b1;
                        o_decoded.ls_op   = LS_LOAD_I32;
                    end
                    M_LOAD_I64_RES,
                    M_LOAD_I64_RES_AQ: begin
                        o_decoded.rawhz_t = RAWHZ_RS1;
                        o_decoded.ls_lq   = 1'b1;
                        o_decoded.ls_op   = LS_LOAD_I64;
                    end
                    default: begin
                        o_decoded.rawhz_t = RAWHZ_RS1_RS2;
                        o_decoded.ls_wen  = 1'b1;
                        o_decoded.ls_sc   = 1'b1;
                        unique case (w_mnemonic)
                            M_CONDSTORE_8:     o_decoded.ls_op = LS_CSTORE_8;
                            M_CONDSTORE_16:    o_decoded.ls_op = LS_CSTORE_16;
                            M_CONDSTORE_32:    o_decoded.ls_op = LS_CSTORE_32;
                            M_CONDSTORE_64:    o_decoded.ls_op = LS_CSTORE_64;
                            M_CONDSTORE_8_RL:  o_decoded.ls_op = LS_CSTORE_8_RL;
                            M_CONDSTORE_16_RL: o_decoded.ls_op = LS_CSTORE_16_RL;
                            M_CONDSTORE_32_RL: o_decoded.ls_op = LS_CSTORE_32_RL;
                            M_CONDSTORE_64_RL: o_decoded.ls_op = LS_CSTORE_64_RL;
                            default:           o_decoded.ls_op = LS_CSTORE_32;
                        endcase
                    end
                endcase
            end

            OP_FENCE: begin
                o_decoded.fu          = FU_MCU;
                o_decoded.imm         = w_imm_i;
            end

            OP_BRANCH: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.rawhz_t     = RAWHZ_RS1_RS2;
                o_decoded.is_branch   = 1'b1;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_b;
            end

            OP_JUMP: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.is_jump     = 1'b1;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_j;
                o_decoded.rf_wen      = (w_rd != X0);
            end

            OP_JUMPR: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.rawhz_t     = RAWHZ_RS1;
                o_decoded.is_jump     = 1'b1;
                o_decoded.is_jalr     = 1'b1;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_i;
                o_decoded.rf_wen      = (w_rd != X0);
            end

            OP_LUI: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.use_pc      = 1'b0;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_u;
                o_decoded.alu_op      = ALU_ADD;
                o_decoded.rs1         = X0;
                o_decoded.rf_wen      = (w_rd != X0);
            end

            OP_AUIPC: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.use_pc      = 1'b1;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_u;
                o_decoded.alu_op      = ALU_ADD;
                o_decoded.rf_wen      = (w_rd != X0);
            end

            OP_IALU: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.rawhz_t     = RAWHZ_RS1;
                o_decoded.use_imm     = 1'b1;
                o_decoded.imm         = w_imm_i;
                o_decoded.rf_wen      = (w_rd != X0);
                unique case (w_mnemonic)
                    M_ADDI_I64:  o_decoded.alu_op = ALU_ADD;
                    M_SLI_I64:   o_decoded.alu_op = ALU_SLL;
                    M_SLTI_I64:  o_decoded.alu_op = ALU_SLT;
                    M_SLTI_U64:  o_decoded.alu_op = ALU_SLTU;
                    M_XORI_64:   o_decoded.alu_op = ALU_XOR;
                    // RV64 shift-immediate encodes a 6-bit shamt.  The
                    // generated mnemonic table's funct7 comparison only
                    // covers shamt[5]==0, so decode funct6 here.
                    M_SRI_U64:   o_decoded.alu_op = ALU_SRL;
                    M_SRI_I64:   o_decoded.alu_op = ALU_SRA;
                    M_ORI_64:    o_decoded.alu_op = ALU_OR;
                    M_ANDI_64:   o_decoded.alu_op = ALU_AND;
                    default:     o_decoded.alu_op = (w_f3 == 3'b101) ?
                                                    (i_instr[31:26] == 6'b010000 ? ALU_SRA : ALU_SRL) :
                                                    ALU_ADD;
                endcase
            end

            OP_RALU: begin
                o_decoded.fu          = FU_ALU;
                o_decoded.rawhz_t     = RAWHZ_RS1_RS2;
                o_decoded.rf_wen      = (w_rd != X0);
                unique case (w_mnemonic)
                    M_ADD_I64:      o_decoded.alu_op = ALU_ADD;
                    M_SUB_I64:      o_decoded.alu_op = ALU_SUB;
                    M_MUL_64_LO:    o_decoded.alu_op = ALU_MUL;
                    M_MUL_I64_HI:   o_decoded.alu_op = ALU_MULH;
                    M_MUL_IU64_HI:  o_decoded.alu_op = ALU_MULHSU;
                    M_MUL_U64_HI:   o_decoded.alu_op = ALU_MULHU;
                    M_SL_I64:       o_decoded.alu_op = ALU_SLL;
                    M_SLT_I64:      o_decoded.alu_op = ALU_SLT;
                    M_SLT_U64:      o_decoded.alu_op = ALU_SLTU;
                    M_XOR_64:       o_decoded.alu_op = ALU_XOR;
                    M_SR_U64:       o_decoded.alu_op = ALU_SRL;
                    M_SR_I64:       o_decoded.alu_op = ALU_SRA;
                    M_OR_64:        o_decoded.alu_op = ALU_OR;
                    M_AND_64:       o_decoded.alu_op = ALU_AND;
                    default:        o_decoded.alu_op = ALU_ADD;
                endcase
            end

            OP_IALUW: begin
                o_decoded.fu       = FU_ALU;
                o_decoded.rawhz_t  = RAWHZ_RS1;
                o_decoded.use_imm  = 1'b1;
                o_decoded.imm      = w_imm_i;
                o_decoded.rf_wen   = (w_rd != X0);
                o_decoded.alu_word = 1'b1;
                unique case (w_mnemonic)
                    M_ADDI_I32: o_decoded.alu_op = ALU_ADD;
                    M_SLI_I32:  o_decoded.alu_op = ALU_SLL;
                    M_SRI_U32:  o_decoded.alu_op = ALU_SRL;
                    M_SRI_I32:  o_decoded.alu_op = ALU_SRA;
                    default:    o_decoded.alu_op = ALU_ADD;
                endcase
            end

            OP_RALUW: begin
                o_decoded.fu       = FU_ALU;
                o_decoded.rawhz_t  = RAWHZ_RS1_RS2;
                o_decoded.rf_wen   = (w_rd != X0);
                o_decoded.alu_word = 1'b1;
                unique case (w_mnemonic)
                    M_ADD_I32: o_decoded.alu_op = ALU_ADD;
                    M_SUB_I32: o_decoded.alu_op = ALU_SUB;
                    M_MUL_I32_LO: o_decoded.alu_op = ALU_MUL;
                    M_SL_I32:  o_decoded.alu_op = ALU_SLL;
                    M_SR_U32:  o_decoded.alu_op = ALU_SRL;
                    M_SR_I32:  o_decoded.alu_op = ALU_SRA;
                    default:   o_decoded.alu_op = ALU_ADD;
                endcase
            end

            OP_SYSTEM: begin
                o_decoded.imm = w_imm_i;
                unique case (w_mnemonic)
                    M_ECALL: begin
                        o_decoded.fu       = FU_MCU;
                        o_decoded.is_ecall = 1'b1;
                    end
                    M_SRET: begin
                        o_decoded.fu      = FU_MCU;
                        o_decoded.is_sret = 1'b1;
                    end
                    M_MRET: begin
                        o_decoded.fu      = FU_MCU;
                        o_decoded.is_mret = 1'b1;
                    end
                    M_WFI: begin
                        o_decoded.fu     = FU_MCU;
                        o_decoded.is_wfi = 1'b1;
                    end
                    M_CSRRW,
                    M_CSRRWI,
                    M_CSRRS,
                    M_CSRRC,
                    M_CSRRSI,
                    M_CSRRCI: begin
                        o_decoded.fu      = FU_CSR;
                        o_decoded.use_imm = csr_op_uses_uimm(w_f3);
                        o_decoded.rawhz_t = (csr_op_uses_uimm(w_f3) || (w_rs1 == X0)) ? RAWHZ_NONE : RAWHZ_RS1;
                        o_decoded.csr_wen = (w_f3 == INST_CSRRW_F3) || (w_rs1 != X0);
                        o_decoded.rf_wen  = (w_rd != X0);
                    end
                    default: ;
                endcase
            end

            default: ;
        endcase
    end

endmodule
