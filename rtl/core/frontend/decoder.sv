/*
 * decoder.sv
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
 * 1. Combinational
 */

`timescale 1ns/1ps
`default_nettype none

import isa_pkg::*;
import frontend_pkg::*;

module frontend_decoder (
    input  logic [INST_W-1:0]         i_instr,
    input  logic [VIR_ADDR_W-1:0]     i_pc,
    output decoded_instr_t            o_decoded
);

    mnemonic_e           w_mnemonic;
    logic [OPCODE_W-1:0] w_opcode;
    logic [4:0]          w_rd;
    logic [4:0]          w_rs1;
    logic [4:0]          w_rs2;
    logic [4:0]          w_rs3;
    logic [2:0]          w_f3;
    logic                w_word_op;
    logic [31:0]         w_imm_i;
    logic [31:0]         w_imm_s;
    logic [31:0]         w_imm_b;
    logic [31:0]         w_imm_u;
    logic [31:0]         w_imm_j;

    always_comb begin
        w_opcode   = inst_opcode(i_instr);
        w_rd       = inst_rd(i_instr);
        w_rs1      = inst_rs1(i_instr);
        w_rs2      = inst_rs2(i_instr);
        w_rs3      = inst_rs3(i_instr);
        w_f3       = inst_funct3(i_instr);
        w_word_op  = (w_opcode == OP_IALUW) || (w_opcode == OP_RALUW);
        w_mnemonic = decode(i_instr);
        w_imm_i    = inst_imm_i(i_instr)[31:0];
        w_imm_s    = inst_imm_s(i_instr)[31:0];
        w_imm_b    = inst_imm_b(i_instr)[31:0];
        w_imm_u    = inst_imm_u(i_instr)[31:0];
        w_imm_j    = inst_imm_j(i_instr)[31:0];

        o_decoded             = '0;
        o_decoded.fu          = FU_ALU;
        o_decoded.fu_ctrl.alu = ALU_ADD;

        unique case (w_opcode)
            OP_LOAD, OP_FLOAD: begin
                o_decoded.fu                      = FU_LSU;
                o_decoded.operands.imm_rs1_rd.imm = w_imm_i;
                o_decoded.operands.imm_rs1_rd.rs1 = w_rs1;
                o_decoded.operands.imm_rs1_rd.rd  = w_rd;

                unique case (w_mnemonic)
                    M_LOAD_I8:   o_decoded.fu_ctrl.lsu.op = LS_LOAD_I8;
                    M_LOAD_I16:  o_decoded.fu_ctrl.lsu.op = LS_LOAD_I16;
                    M_LOAD_I64:  o_decoded.fu_ctrl.lsu.op = LS_LOAD_I64;
                    M_LOAD_U8:   o_decoded.fu_ctrl.lsu.op = LS_LOAD_U8;
                    M_LOAD_U16:  o_decoded.fu_ctrl.lsu.op = LS_LOAD_U16;
                    M_LOAD_U32:  o_decoded.fu_ctrl.lsu.op = LS_LOAD_U32;
                    M_LOAD_F16:  o_decoded.fu_ctrl.lsu.op = LS_LOAD_F16;
                    M_LOAD_BF16: o_decoded.fu_ctrl.lsu.op = LS_LOAD_BF16;
                    default:     o_decoded.fu_ctrl.lsu.op = LS_LOAD_I32;
                endcase
            end

            OP_STORE, OP_FSTORE: begin
                o_decoded.fu                       = FU_LSU;
                o_decoded.operands.imm_rs1_rs2.imm = w_imm_s;
                o_decoded.operands.imm_rs1_rs2.rs1 = w_rs1;
                o_decoded.operands.imm_rs1_rs2.rs2 = w_rs2;

                unique case (w_mnemonic)
                    M_STORE_8:    o_decoded.fu_ctrl.lsu.op = LS_STORE_8;
                    M_STORE_16:   o_decoded.fu_ctrl.lsu.op = LS_STORE_16;
                    M_STORE_64:   o_decoded.fu_ctrl.lsu.op = LS_STORE_64;
                    M_STORE_F16:  o_decoded.fu_ctrl.lsu.op = LS_STORE_F16;
                    M_STORE_BF16: o_decoded.fu_ctrl.lsu.op = LS_STORE_BF16;
                    default:      o_decoded.fu_ctrl.lsu.op = LS_STORE_32;
                endcase
            end

            OP_BRANCH: begin
                o_decoded.fu                  = FU_BRANCH;
                o_decoded.operands.branch.pc  = i_pc;
                o_decoded.operands.branch.imm = w_imm_b;
                o_decoded.operands.branch.rs1 = w_rs1;
                o_decoded.operands.branch.rs2 = w_rs2;

                unique case (w_f3)
                    3'b000:  o_decoded.fu_ctrl.branch.op = BRANCH_EQ;
                    3'b001:  o_decoded.fu_ctrl.branch.op = BRANCH_NE;
                    3'b100:  o_decoded.fu_ctrl.branch.op = BRANCH_LT;
                    3'b101:  o_decoded.fu_ctrl.branch.op = BRANCH_GE;
                    3'b110:  o_decoded.fu_ctrl.branch.op = BRANCH_LTU;
                    default: o_decoded.fu_ctrl.branch.op = BRANCH_GEU;
                endcase
            end

            OP_JUMP: begin
                o_decoded.fu                     = FU_BRANCH;
                o_decoded.operands.pc_imm_rd.pc  = i_pc;
                o_decoded.operands.pc_imm_rd.imm = w_imm_j;
                o_decoded.operands.pc_imm_rd.rd  = w_rd;
                o_decoded.fu_ctrl.branch.op = BRANCH_JAL;
            end

            OP_JUMPR: begin
                o_decoded.fu                = FU_BRANCH;
                o_decoded.operands.jalr.pc  = i_pc;
                o_decoded.operands.jalr.imm = w_imm_i;
                o_decoded.operands.jalr.rs1 = w_rs1;
                o_decoded.operands.jalr.rd  = w_rd;
                o_decoded.fu_ctrl.branch.op = BRANCH_JALR;
            end

            OP_LUI, OP_AUIPC: begin
                o_decoded.fu                     = FU_ALU;
                o_decoded.operands.pc_imm_rd.pc  = i_pc;
                o_decoded.operands.pc_imm_rd.imm = w_imm_u;
                o_decoded.operands.pc_imm_rd.rd  = w_rd;
                o_decoded.fu_ctrl.alu = (w_opcode == OP_LUI) ? ALU_LUI : ALU_AUIPC;
            end

            OP_IALU, OP_IALUW: begin
                o_decoded.fu = FU_ALU;
                o_decoded.operands.imm_rs1_rd.imm = w_imm_i;
                o_decoded.operands.imm_rs1_rd.rs1 = w_rs1;
                o_decoded.operands.imm_rs1_rd.rd  = w_rd;

                unique case (w_f3)
                    3'b001:  o_decoded.fu_ctrl.alu = w_word_op ? ALU_SLLIW : ALU_SLLI;
                    3'b010:  o_decoded.fu_ctrl.alu = ALU_SLTI;
                    3'b011:  o_decoded.fu_ctrl.alu = ALU_SLTIU;
                    3'b100:  o_decoded.fu_ctrl.alu = ALU_XORI;
                    3'b101:  o_decoded.fu_ctrl.alu = i_instr[30] ? (w_word_op ? ALU_SRAIW : ALU_SRAI) : (w_word_op ? ALU_SRLIW : ALU_SRLI);
                    3'b110:  o_decoded.fu_ctrl.alu = ALU_ORI;
                    3'b111:  o_decoded.fu_ctrl.alu = ALU_ANDI;
                    default: o_decoded.fu_ctrl.alu = w_word_op ? ALU_ADDIW : ALU_ADDI;
                endcase
            end

            OP_RALU, OP_RALUW: begin
                o_decoded.operands.rs1_rs2_rd.rs1 = w_rs1;
                o_decoded.operands.rs1_rs2_rd.rs2 = w_rs2;
                o_decoded.operands.rs1_rs2_rd.rd  = w_rd;

                if (i_instr[31:25] == 7'b0000001) begin
                    o_decoded.fu = FU_MUL;

                    unique case (w_f3)
                        3'b000:  o_decoded.fu_ctrl.mul = w_word_op ? ALU_MULW : ALU_MUL;
                        3'b001:  o_decoded.fu_ctrl.mul = ALU_MULH;
                        3'b010:  o_decoded.fu_ctrl.mul = ALU_MULHSU;
                        3'b011:  o_decoded.fu_ctrl.mul = ALU_MULHU;
                        default: o_decoded.fu_ctrl.mul = ALU_MUL;
                    endcase
                end else begin
                    o_decoded.fu = FU_ALU;

                    unique case (w_f3)
                        3'b000:  o_decoded.fu_ctrl.alu = i_instr[30] ? (w_word_op ? ALU_SUBW : ALU_SUB) : (w_word_op ? ALU_ADDW : ALU_ADD);
                        3'b001:  o_decoded.fu_ctrl.alu = w_word_op ? ALU_SLLW : ALU_SLL;
                        3'b010:  o_decoded.fu_ctrl.alu = ALU_SLT;
                        3'b011:  o_decoded.fu_ctrl.alu = ALU_SLTU;
                        3'b100:  o_decoded.fu_ctrl.alu = ALU_XOR;
                        3'b101:  o_decoded.fu_ctrl.alu = i_instr[30] ? (w_word_op ? ALU_SRAW : ALU_SRA) : (w_word_op ? ALU_SRLW : ALU_SRL);
                        3'b110:  o_decoded.fu_ctrl.alu = ALU_OR;
                        default: o_decoded.fu_ctrl.alu = ALU_AND;
                    endcase
                end
            end

            OP_SYSTEM: begin
                unique case (w_mnemonic)
                    M_CSRRW,
                    M_CSRRS,
                    M_CSRRC,
                    M_CSRRWI,
                    M_CSRRSI,
                    M_CSRRCI: begin
                        o_decoded.fu = FU_SYSTEM;

                        unique case (w_f3)
                            3'b001:  o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RW;
                            3'b010:  o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RS;
                            3'b011:  o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RC;
                            3'b101:  o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RWI;
                            3'b110:  o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RSI;
                            default: o_decoded.fu_ctrl.system.op = SYSTEM_CSR_RCI;
                        endcase

                        if (w_f3[2]) begin
                            o_decoded.operands.csraddr_zimm_rd.csraddr = i_instr[31:20];
                            o_decoded.operands.csraddr_zimm_rd.zimm    = w_rs1;
                            o_decoded.operands.csraddr_zimm_rd.rd      = w_rd;
                        end else begin
                            o_decoded.operands.csraddr_rs1_rd.csraddr = i_instr[31:20];
                            o_decoded.operands.csraddr_rs1_rd.rs1     = w_rs1;
                            o_decoded.operands.csraddr_rs1_rd.rd      = w_rd;
                        end
                    end
                    M_ECALL: begin
                        o_decoded.fu                = FU_SYSTEM;
                        o_decoded.fu_ctrl.system.op = SYSTEM_ECALL;
                        o_decoded.events.ecall      = 1'b1;
                    end
                    M_SRET: begin
                        o_decoded.fu                = FU_SYSTEM;
                        o_decoded.fu_ctrl.system.op = SYSTEM_SRET;
                        o_decoded.events.sret       = 1'b1;
                    end
                    M_MRET: begin
                        o_decoded.fu                = FU_SYSTEM;
                        o_decoded.fu_ctrl.system.op = SYSTEM_MRET;
                        o_decoded.events.mret       = 1'b1;
                    end
                    M_WFI: begin
                        o_decoded.fu                = FU_SYSTEM;
                        o_decoded.fu_ctrl.system.op = SYSTEM_WFI;
                        o_decoded.events.wfi        = 1'b1;
                    end
                    default: ;
                endcase
            end

            default: ;
        endcase
    end
endmodule: frontend_decoder

`default_nettype wire
