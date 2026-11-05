/*
 * alu.sv
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
 * 1. Mainly these separate units exists
 *   - Adder * 2
 *   - Multiplier 2XLEN+1 bit multiplier
 *   - Barrel shifter
 *   - xor, or, and
 * 2. In cycle N (s1_*)
 *   - latch the inputs, type of op, thread id etc. and takes basic decision on those
 *   - then put to the relvent unit
 * 3. In cycle N+1 (s2_*)
 *   - get the result from the relvent unit and put to the output
 * 4. No DIV,REM support
 */

`timescale 1ns/1ps
`default_nettype none

import core_pkg::*;
import isa_pkg::*;

module alu (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic [XLEN-1:0]                 i_field1,
    input  logic [XLEN-1:0]                 i_field2,
    input  alu_operation_e                  i_alu_op,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_thread_id,
    output logic                            o_req_ready,
    input  logic                            i_req_valid,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_res_thrd_id,
    output logic                            o_res_valid,
    input  logic                            i_res_ready,
    output logic [XLEN-1:0]                 o_result
);
    localparam int MUL_W = (2 * XLEN) + 1;

    /* Functional units--- */

    logic [XLEN-1:0]         w_adder_a;
    logic [XLEN-1:0]         w_adder_b;
    logic                    w_adder_is_sub;
    logic [XLEN-1:0]         w_adder_result;
    logic                    w_adder_lt_signed;
    logic                    w_adder_lt_unsigned;

    logic                    w_mul_en;
    logic signed [XLEN:0]    w_mul_a;
    logic signed [XLEN:0]    w_mul_b;
    logic signed [MUL_W-1:0] w_mul_result;

    logic [XLEN-1:0]         w_shift_a;
    logic [XLEN-1:0]         w_shift_b;
    alu_operation_e          w_shift_op;
    logic [XLEN-1:0]         w_shift_result;

    logic [XLEN-1:0]         w_logic_a;
    logic [XLEN-1:0]         w_logic_b;
    alu_operation_e          w_logic_op;
    logic [XLEN-1:0]         w_logic_result;

    alu_adder u_adder (
        .i_a           (w_adder_a),
        .i_b           (w_adder_b),
        .i_is_sub      (w_adder_is_sub),
        .o_result      (w_adder_result),
        .o_lt_signed   (w_adder_lt_signed),
        .o_lt_unsigned (w_adder_lt_unsigned)
    );
    alu_multiplier u_multiplier (
        .i_clk         (i_clk),
        .i_en          (w_mul_en),
        .i_a           (w_mul_a),
        .i_b           (w_mul_b),
        .o_product     (w_mul_result)
    );
    alu_shifter u_shifter (
        .i_a           (w_shift_a),
        .i_b           (w_shift_b),
        .i_op          (w_shift_op),
        .o_shift       (w_shift_result)
    );
    alu_logic u_logic (
        .i_a           (w_logic_a),
        .i_b           (w_logic_b),
        .i_op          (w_logic_op),
        .o_logic       (w_logic_result)
    );
    /* ---Functional units */


    /* s0--- */
    logic                            s1_valid;
    logic [XLEN-1:0]                 s1_op_a;
    logic [XLEN-1:0]                 s1_op_b;
    alu_operation_e                  s1_alu_op;
    logic [$clog2(NUM_HW_THRDS)-1:0] s1_thrd_id;

    logic [XLEN-1:0]                 s0_op_a;
    logic [XLEN-1:0]                 s0_op_b;
    logic                            s0_is_imm;
    logic signed [XLEN:0]            s0_mul_a;
    logic signed [XLEN:0]            s0_mul_b;
    logic                            s0_ready;
    logic                            s0_req_fire;

    always_comb begin
        unique case (i_alu_op)
            ALU_ADDI,  ALU_SLLI,  ALU_SRLI,  ALU_SRAI,
            ALU_SLTI,  ALU_SLTIU, ALU_XORI,  ALU_ORI,
            ALU_ANDI,  ALU_ADDIW, ALU_SLLIW, ALU_SRLIW,
            ALU_SRAIW, ALU_LUI,   ALU_AUIPC:
                s0_is_imm = 1'b1;
            default:
                s0_is_imm = 1'b0;
        endcase
    end

    assign s0_op_a     = i_field1;
    assign s0_op_b     = s0_is_imm ? {{(XLEN-32){i_field2[31]}}, i_field2[31:0]}: i_field2;
    assign s0_ready    = !s1_valid || s1_to_s2;
    assign s0_req_fire = i_req_valid && s0_ready;

    always_comb begin
        unique case (i_alu_op)
            ALU_MULH: begin
                s0_mul_a = {s0_op_a[XLEN-1], s0_op_a};
                s0_mul_b = {s0_op_b[XLEN-1], s0_op_b};
            end
            ALU_MULHSU: begin
                s0_mul_a = {s0_op_a[XLEN-1], s0_op_a};
                s0_mul_b = {1'b0, s0_op_b};
            end
            default: begin
                s0_mul_a = {1'b0, s0_op_a};
                s0_mul_b = {1'b0, s0_op_b};
            end
        endcase
    end

    assign w_mul_en = s0_req_fire;
    assign w_mul_a  = s0_mul_a;
    assign w_mul_b  = s0_mul_b;


    always_ff @(posedge i_clk) begin : s0_pr_s1
        if (!i_rst_n) begin
            s1_valid   <= 1'b0;
            s1_op_a    <= '0;
            s1_op_b    <= '0;
            s1_alu_op  <= ALU_ADD;
            s1_thrd_id <= '0;
        end
        else begin
            if (s1_to_s2) begin
                s1_valid <= 1'b0;
            end
            if (s0_req_fire) begin
                s1_valid   <= 1'b1;
                s1_op_a    <= s0_op_a;
                s1_op_b    <= s0_op_b;
                s1_alu_op  <= i_alu_op;
                s1_thrd_id <= i_thread_id;
            end
        end
    end : s0_pr_s1
    /* ---s0 */

    /* s1--- */
    logic                            s2_valid;
    logic [XLEN-1:0]                 s2_result;
    logic [$clog2(NUM_HW_THRDS)-1:0] s2_thrd_id;

    logic                            s1_to_s2;
    logic [XLEN-1:0]                 s1_result_comb;


    assign w_adder_a      = s1_op_a;
    assign w_adder_b      = s1_op_b;
    assign w_adder_is_sub = (s1_alu_op == ALU_SUB)  || (s1_alu_op == ALU_SUBW)  ||
                            (s1_alu_op == ALU_SLT)  || (s1_alu_op == ALU_SLTI)  ||
                            (s1_alu_op == ALU_SLTU) || (s1_alu_op == ALU_SLTIU);
    assign w_shift_a      = s1_op_a;
    assign w_shift_b      = s1_op_b;
    assign w_shift_op     = s1_alu_op;
    assign w_logic_a      = s1_op_a;
    assign w_logic_b      = s1_op_b;
    assign w_logic_op     = s1_alu_op;

    always_comb begin
        unique case (s1_alu_op)
            ALU_ADD,   ALU_ADDI,
            ALU_SUB,   ALU_AUIPC:
                s1_result_comb = w_adder_result;
            ALU_SLL,   ALU_SLLI,
            ALU_SRL,   ALU_SRLI,
            ALU_SRA,   ALU_SRAI:
                s1_result_comb = w_shift_result;
            ALU_XOR,   ALU_XORI,
            ALU_OR,    ALU_ORI,
            ALU_AND,   ALU_ANDI:
                s1_result_comb = w_logic_result;
            ALU_SLT,   ALU_SLTI:
                s1_result_comb = {{(XLEN-1){1'b0}}, w_adder_lt_signed};
            ALU_SLTU,  ALU_SLTIU:
                s1_result_comb = {{(XLEN-1){1'b0}}, w_adder_lt_unsigned};
            ALU_ADDW,  ALU_ADDIW,
            ALU_SUBW:
                s1_result_comb = {{(XLEN-32){w_adder_result[31]}},
                                 w_adder_result[31:0]};
            ALU_SLLW,  ALU_SLLIW,
            ALU_SRLW,  ALU_SRLIW,
            ALU_SRAW,  ALU_SRAIW:
                s1_result_comb = {{(XLEN-32){w_shift_result[31]}},
                                 w_shift_result[31:0]};
            ALU_LUI:
                s1_result_comb = s1_op_b;
            ALU_MUL:
                s1_result_comb = w_mul_result[XLEN-1:0];
            ALU_MULH,  ALU_MULHU,
            ALU_MULHSU:
                s1_result_comb = w_mul_result[(2*XLEN)-1:XLEN];
            default:
                s1_result_comb = '0;
        endcase
    end

    assign s1_to_s2 = s1_valid && (!s2_valid || i_res_ready);

    always_ff @(posedge i_clk) begin : s1_pr_s2
        if (!i_rst_n) begin
            s2_valid   <= 1'b0;
            s2_result  <= '0;
            s2_thrd_id <= '0;
        end
        else begin
            if (s1_to_s2) begin
                s2_valid   <= 1'b1;
                s2_result  <= s1_result_comb;
                s2_thrd_id <= s1_thrd_id;
            end
            else if (s2_valid && i_res_ready) begin
                s2_valid <= 1'b0;
            end
        end
    end : s1_pr_s2
    /* ---s1 */


    /* s2--- */
    assign o_req_ready   = s0_ready;
    assign o_res_valid   = s2_valid;
    assign o_result      = s2_result;
    assign o_res_thrd_id = s2_thrd_id;
    /* ---s2 */

endmodule : alu

module alu_adder (
    input  logic [XLEN-1:0] i_a,
    input  logic [XLEN-1:0] i_b,
    input  logic            i_is_sub,
    output logic [XLEN-1:0] o_result,
    output logic            o_lt_signed,
    output logic            o_lt_unsigned
);
    logic [XLEN:0] w_add_result;

    assign w_add_result  = {1'b0, i_a} + {1'b0, i_b ^ {XLEN{i_is_sub}}} + i_is_sub;
    assign o_result      = w_add_result[XLEN-1:0];
    assign o_lt_unsigned = i_is_sub && !w_add_result[XLEN];
    assign o_lt_signed = i_is_sub && ((i_a[XLEN-1] != i_b[XLEN-1])
                                  ? i_a[XLEN-1] : o_result[XLEN-1]);

endmodule : alu_adder

module alu_multiplier (
    input  logic                         i_clk,
    input  logic                         i_en,
    input  logic signed [XLEN:0]         i_a,
    input  logic signed [XLEN:0]         i_b,
    output logic signed [(2*XLEN):0]     o_product
);
    always_ff @(posedge i_clk) begin
        if (i_en) begin
            o_product <= i_a * i_b;
        end
    end
endmodule : alu_multiplier

module alu_shifter (
    input  logic [XLEN-1:0] i_a,
    input  logic [XLEN-1:0] i_b,
    input  alu_operation_e  i_op,
    output logic [XLEN-1:0] o_shift
);
    localparam int SHAMT_W = $clog2(XLEN);

    always_comb begin
        unique case (i_op)
            ALU_SLL,  ALU_SLLI:  o_shift = i_a << i_b[SHAMT_W-1:0];
            ALU_SRL,  ALU_SRLI:  o_shift = i_a >> i_b[SHAMT_W-1:0];
            ALU_SRA,  ALU_SRAI:  o_shift = $signed(i_a) >>> i_b[SHAMT_W-1:0];
            ALU_SLLW, ALU_SLLIW: o_shift = i_a[31:0] << i_b[4:0];
            ALU_SRLW, ALU_SRLIW: o_shift = i_a[31:0] >> i_b[4:0];
            ALU_SRAW, ALU_SRAIW: o_shift = $signed(i_a[31:0]) >>> i_b[4:0];
            default: o_shift = '0;
        endcase
    end
endmodule : alu_shifter

module alu_logic (
    input  logic [XLEN-1:0] i_a,
    input  logic [XLEN-1:0] i_b,
    input  alu_operation_e  i_op,
    output logic [XLEN-1:0] o_logic
);
    always_comb begin
        unique case (i_op)
            ALU_XOR, ALU_XORI: o_logic = i_a ^ i_b;
            ALU_OR,  ALU_ORI:  o_logic = i_a | i_b;
            ALU_AND, ALU_ANDI: o_logic = i_a & i_b;
            default:           o_logic = '0;
        endcase
    end
endmodule : alu_logic

`default_nettype wire
