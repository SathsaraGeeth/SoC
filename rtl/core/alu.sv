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
import core_pkg::issue_instr_t;
import core_pkg::NUM_HW_THRDS;
import core_pkg::VIR_ADDR_W;
import isa_pkg::*;

module alu (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  issue_instr_t                    i_issued_instr       [1:0],
    output logic                            o_req_ready          [1:0],
    input  logic                            i_req_valid          [1:0],
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_res_thrd_id        [1:0],
    output logic [XLEN-1:0]                 o_br_target          [1:0],
    output logic                            o_br_taken           [1:0],
    output logic                            o_res_valid          [1:0],
    input  logic                            i_res_ready          [1:0],
    output logic [VIR_ADDR_W-1:0]           o_result             [1:0]
);
    for (genvar i = 0; i < 2; i++) begin: gen_lane
        alu_lane #(
            .BRANCH_LANE                   (1'b1)
        ) lane (
            .i_clk                          (i_clk),
            .i_rst_n                        (i_rst_n),
            .i_issued_instr                 (i_issued_instr[i]),
            .o_req_ready                    (o_req_ready[i]),
            .i_req_valid                    (i_req_valid[i]),
            .o_res_thrd_id                  (o_res_thrd_id[i]),
            .o_br_target                    (o_br_target[i]),
            .o_br_taken                     (o_br_taken[i]),
            .o_res_valid                    (o_res_valid[i]),
            .i_res_ready                    (i_res_ready[i]),
            .o_result                       (o_result[i])
        );
    end
endmodule: alu


module alu_lane #(
    parameter logic BRANCH_LANE = 1'b0
) (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  issue_instr_t                    i_issued_instr,
    output logic                            o_req_ready,
    input  logic                            i_req_valid,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_res_thrd_id,
    output logic [XLEN-1:0]                 o_br_target,
    output logic                            o_br_taken,
    output logic                            o_res_valid,
    input  logic                            i_res_ready,
    output logic [VIR_ADDR_W-1:0]           o_result
);
    localparam int MUL_W = (2 * XLEN) + 1;
    localparam logic [XLEN-1:0] PC_STEP = XLEN'(INST_W / 8);

    /**--- */
    logic [XLEN-1:0]            w_adder_a;
    logic [XLEN-1:0]            w_adder_b;
    logic                       w_adder_is_sub;
    logic [XLEN-1:0]            w_adder_result;
    logic                       w_adder_lt_signed;
    logic                       w_adder_lt_unsigned;

    logic [XLEN-1:0]            w_addr_adder_a;
    logic [XLEN-1:0]            w_addr_adder_b;
    logic [XLEN-1:0]            w_addr_adder_result;

    logic                       w_mul_clk;
    logic signed [XLEN:0]       w_mul_a;
    logic signed [XLEN:0]       w_mul_b;
    logic signed [MUL_W-1:0]    w_mul_comb;

    logic [XLEN-1:0]            w_shift_a;
    logic [XLEN-1:0]            w_shift_b;
    alu_op_e                    w_shift_op; 
    logic [XLEN-1:0]            w_shift_result;

    logic [XLEN-1:0]            w_logic_a;
    logic [XLEN-1:0]            w_logic_b;
    alu_op_e                    w_logic_op;
    logic [XLEN-1:0]            w_logic_result;

    alu_adder u_adder (
        .i_a                    (w_adder_a),
        .i_b                    (w_adder_b),
        .i_is_sub               (w_adder_is_sub),
        .o_result               (w_adder_result),
        .o_lt_signed            (w_adder_lt_signed),
        .o_lt_unsigned          (w_adder_lt_unsigned)
    );
    if (BRANCH_LANE) begin: gen_addr_adder
        alu_adder u_addr_adder (
            .i_a                    (w_addr_adder_a),
            .i_b                    (w_addr_adder_b),
            .i_is_sub               (1'b0),
            .o_result               (w_addr_adder_result),
            .o_lt_signed            (),
            .o_lt_unsigned          ()
        );
    end else begin: gen_no_addr_adder
        assign w_addr_adder_result = '0;
    end
    alu_multiplier u_multiplier (
        .i_clk                  (w_mul_clk),
        .i_a                    (w_mul_a),
        .i_b                    (w_mul_b),
        .o_product              (w_mul_comb)
    );
    alu_shifter u_shifter (
        .i_a                    (w_shift_a),
        .i_b                    (w_shift_b),
        .i_op                   (w_shift_op),
        .o_shift                (w_shift_result)
    );
    alu_logic u_logic (
        .i_a                    (w_logic_a),
        .i_b                    (w_logic_b),
        .i_op                   (w_logic_op),
        .o_logic                (w_logic_result)
    );
    /* ---**/

    /* s0--- */
    // public s1_*
    logic                                   s1_valid;
    logic [XLEN-1:0]                        s1_op_a;
    logic [XLEN-1:0]                        s1_op_b;
    logic [XLEN-1:0]                        s1_rs1_data;
    logic [XLEN-1:0]                        s1_rs2_data;
    logic                                   s1_alu_word;
    logic [XLEN-1:0]                        s1_br_taken_target;
    logic                                   s1_is_jump;
    logic                                   s1_is_jalr;
    logic                                   s1_is_branch;
    logic [2:0]                             s1_funct3;
    alu_op_e                                s1_alu_op;
    logic [$clog2(NUM_HW_THRDS)-1:0]        s1_thrd_id;

    // private s0_*
    logic [XLEN-1:0]                        s0_op_a;
    logic [XLEN-1:0]                        s0_op_b;
    logic [XLEN-1:0]                        s0_addr_adder_a;
    logic [XLEN-1:0]                        s0_addr_adder_b;
    logic [XLEN-1:0]                        s0_taken_target;
    logic                                   s0_is_control_flow;
    logic signed [XLEN:0]                   s0_mul_a;
    logic signed [XLEN:0]                   s0_mul_b;
    logic                                   s0_ready;
    logic                                   s0_req_fire;
    logic                                   s1_to_s2;

    // s0 combinational logic
    assign s0_op_a              = i_issued_instr.instr.is_jump ? i_issued_instr.instr.pc :
                                  i_issued_instr.instr.use_pc  ? i_issued_instr.instr.pc :
                                                                i_issued_instr.rs1_data;
    assign s0_op_b              = i_issued_instr.instr.use_imm ? i_issued_instr.instr.imm : i_issued_instr.rs2_data;
    assign s0_is_control_flow   = i_issued_instr.instr.is_branch || i_issued_instr.instr.is_jump;
    assign s0_addr_adder_a      = !s0_is_control_flow ? '0 :
                                  i_issued_instr.instr.is_jalr ? i_issued_instr.rs1_data :
                                  i_issued_instr.instr.pc;
    assign s0_addr_adder_b      = s0_is_control_flow ? i_issued_instr.instr.imm : '0;
    assign s0_taken_target      = i_issued_instr.instr.is_jalr ?
                                  (w_addr_adder_result & ~{{(XLEN-1){1'b0}}, 1'b1}) :
                                  w_addr_adder_result;
    assign s0_ready             = !s1_valid || s1_to_s2;
    assign s0_req_fire          = i_req_valid && s0_ready;
    assign w_mul_clk            = i_clk;
    assign w_mul_a              = s0_mul_a;
    assign w_mul_b              = s0_mul_b;
    assign w_addr_adder_a       = s0_addr_adder_a;
    assign w_addr_adder_b       = s0_addr_adder_b;

    always_comb begin
        case (i_issued_instr.instr.alu_op)
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

    // s0->s1 registering
    always_ff @(posedge i_clk) begin: s0_pr_s1
        if (!i_rst_n) begin
            s1_valid           <= 1'b0;
            s1_op_a            <= '0;
            s1_op_b            <= '0;
            s1_rs1_data        <= '0;
            s1_rs2_data        <= '0;
            s1_alu_word        <= 1'b0;
            s1_br_taken_target <= '0;
            s1_is_jump         <= 1'b0;
            s1_is_jalr         <= 1'b0;
            s1_is_branch       <= 1'b0;
            s1_funct3          <= '0;
            s1_alu_op          <= ALU_ADD;
            s1_thrd_id         <= '0;
        end else begin
            if (s1_to_s2) begin
                s1_valid           <= 1'b0;
            end
            if (s0_req_fire) begin
                s1_valid           <= 1'b1;
                s1_op_a            <= s0_op_a;
                s1_op_b            <= s0_op_b;
                s1_rs1_data        <= i_issued_instr.rs1_data;
                s1_rs2_data        <= i_issued_instr.rs2_data;
                s1_alu_word        <= i_issued_instr.instr.alu_word;
                s1_br_taken_target <= s0_taken_target;
                s1_is_jump         <= i_issued_instr.instr.is_jump;
                s1_is_jalr         <= i_issued_instr.instr.is_jalr;
                s1_is_branch       <= i_issued_instr.instr.is_branch;
                s1_funct3          <= i_issued_instr.instr.funct3;
                s1_alu_op          <= i_issued_instr.instr.alu_op;
                s1_thrd_id         <= i_issued_instr.thrd_id;
            end
        end
    end: s0_pr_s1
    /* ---s0 */

    /* s1--- */
    // public s2_*
    logic                                   s2_valid;
    logic [XLEN-1:0]                        s2_op_a;
    logic [XLEN-1:0]                        s2_op_b;
    logic [XLEN-1:0]                        s2_rs1_data;
    logic [XLEN-1:0]                        s2_rs2_data;
    logic                                   s2_alu_word;
    logic [XLEN-1:0]                        s2_br_taken_target;
    logic                                   s2_is_jump;
    logic                                   s2_is_jalr;
    logic                                   s2_is_branch;
    logic [2:0]                             s2_funct3;
    alu_op_e                                s2_alu_op;
    logic signed [MUL_W-1:0]                s2_mul_result;
    logic [$clog2(NUM_HW_THRDS)-1:0]        s2_thrd_id;

    // s1 combinational logic
    // s1->s2 registering
    always_ff @(posedge i_clk) begin: s1_pr_s2
        if (!i_rst_n) begin
            s2_valid           <= 1'b0;
            s2_op_a            <= '0;
            s2_op_b            <= '0;
            s2_rs1_data        <= '0;
            s2_rs2_data        <= '0;
            s2_alu_word        <= 1'b0;
            s2_br_taken_target <= '0;
            s2_is_jump         <= 1'b0;
            s2_is_jalr         <= 1'b0;
            s2_is_branch       <= 1'b0;
            s2_funct3          <= '0;
            s2_alu_op          <= ALU_ADD;
            s2_mul_result      <= '0;
            s2_thrd_id         <= '0;
        end else begin
            if (s1_to_s2) begin
                s2_valid           <= 1'b1;
                s2_op_a            <= s1_op_a;
                s2_op_b            <= s1_op_b;
                s2_rs1_data        <= s1_rs1_data;
                s2_rs2_data        <= s1_rs2_data;
                s2_alu_word        <= s1_alu_word;
                s2_br_taken_target <= s1_br_taken_target;
                s2_is_jump         <= s1_is_jump;
                s2_is_jalr         <= s1_is_jalr;
                s2_is_branch       <= s1_is_branch;
                s2_funct3          <= s1_funct3;
                s2_alu_op          <= s1_alu_op;
                s2_mul_result      <= w_mul_comb;
                s2_thrd_id         <= s1_thrd_id;
            end else if (s2_valid && i_res_ready) begin
                s2_valid <= 1'b0;
            end
        end
    end: s1_pr_s2
    /* ---s1 */

    /* s2--- */
    // private s2_*
    logic                                   s2_ready;
    logic [XLEN-1:0]                        s2_adder_a;
    logic [XLEN-1:0]                        s2_adder_b;
    logic                                   s2_adder_is_sub;
    logic [XLEN-1:0]                        s2_adder_result;
    logic                                   s2_adder_lt_signed;
    logic                                   s2_adder_lt_unsigned;
    logic [XLEN-1:0]                        s2_shift_result;
    logic [XLEN-1:0]                        s2_logic_result;
    logic [XLEN-1:0]                        s2_result_comb;
    logic                                   s2_branch_taken_comb;
    logic [XLEN-1:0]                        s2_output_result;

    // s2 combinational logic
    assign s2_ready             = !s2_valid || i_res_ready;
    assign s1_to_s2             = s1_valid && s2_ready;
    assign s2_adder_a           = s2_is_branch ? s2_rs1_data : s2_op_a;
    assign s2_adder_b           = s2_is_branch ? s2_rs2_data : (s2_is_jump || s2_is_jalr) ? PC_STEP : s2_op_b;
    assign s2_adder_is_sub      = s2_is_branch || s2_alu_op == ALU_SUB || s2_alu_op == ALU_SLT || s2_alu_op == ALU_SLTU;
    assign s2_adder_result      = w_adder_result;
    assign s2_adder_lt_signed   = w_adder_lt_signed;
    assign s2_adder_lt_unsigned = w_adder_lt_unsigned;
    assign s2_shift_result      = w_shift_result;
    assign s2_logic_result      = w_logic_result;
    assign w_adder_a            = s2_adder_a;
    assign w_adder_b            = s2_adder_b;
    assign w_adder_is_sub       = s2_adder_is_sub;
    assign w_shift_a            = s2_op_a;
    assign w_shift_b            = s2_op_b;
    assign w_shift_op           = s2_alu_op;
    assign w_logic_a            = s2_op_a;
    assign w_logic_b            = s2_op_b;
    assign w_logic_op           = s2_alu_op;
    assign s2_output_result     = (s2_is_jump || s2_is_jalr) ? s2_adder_result : s2_result_comb;

    always_comb begin
        s2_branch_taken_comb = s2_is_jump;
        if (s2_is_branch) begin
            case (s2_funct3)
                3'b000:  s2_branch_taken_comb = (s2_adder_result == '0);
                3'b001:  s2_branch_taken_comb = (s2_adder_result != '0);
                3'b100:  s2_branch_taken_comb = s2_adder_lt_signed;
                3'b101:  s2_branch_taken_comb = !s2_adder_lt_signed;
                3'b110:  s2_branch_taken_comb = s2_adder_lt_unsigned;
                3'b111:  s2_branch_taken_comb = !s2_adder_lt_unsigned;
                default: s2_branch_taken_comb = 1'b0;
            endcase
        end
    end

    always_comb begin
        case (s2_alu_op)
            ALU_ADD,
            ALU_SUB:    s2_result_comb = s2_adder_result;
            ALU_SLL,
            ALU_SRL,
            ALU_SRA:    s2_result_comb = s2_shift_result;
            ALU_XOR,
            ALU_OR,
            ALU_AND:    s2_result_comb = s2_logic_result;
            ALU_SLT:    s2_result_comb = {{(XLEN-1){1'b0}}, s2_adder_lt_signed};
            ALU_SLTU:   s2_result_comb = {{(XLEN-1){1'b0}}, s2_adder_lt_unsigned};
            ALU_MUL:    s2_result_comb = s2_mul_result[XLEN-1:0];
            ALU_MULH,
            ALU_MULHSU,
            ALU_MULHU:  s2_result_comb = s2_mul_result[(2*XLEN)-1:XLEN];
            default:    s2_result_comb = '0;
        endcase
        if (s2_alu_word)
            s2_result_comb = {{(XLEN-32){s2_result_comb[31]}}, s2_result_comb[31:0]};
    end

    assign o_req_ready   = s0_ready;
    assign o_res_valid   = s2_valid;
    assign o_result      = s2_output_result;
    assign o_br_target   = s2_br_taken_target;
    assign o_br_taken    = s2_branch_taken_comb;
    assign o_res_thrd_id = s2_thrd_id;
    /* ---s2 */
endmodule: alu_lane


module alu_adder (
    input  logic    [XLEN-1:0]          i_a,
    input  logic    [XLEN-1:0]          i_b,
    input  logic                        i_is_sub,
    output logic    [XLEN-1:0]          o_result,
    output logic                        o_lt_signed,
    output logic                        o_lt_unsigned
);
    logic [XLEN-1:0]                    w_add_b;
    logic [XLEN:0]                      w_add_result;

    always_comb begin
        w_add_b       = i_is_sub ? ~i_b : i_b;
        w_add_result  = {1'b0, i_a} + {1'b0, w_add_b} + {{XLEN{1'b0}}, i_is_sub};
        o_result      = w_add_result[XLEN-1:0];
        o_lt_unsigned = i_is_sub && !w_add_result[XLEN];
        o_lt_signed   = i_is_sub && ((i_a[XLEN-1] != i_b[XLEN-1]) ? i_a[XLEN-1] : o_result[XLEN-1]);
    end
endmodule: alu_adder

module alu_multiplier (
    input  logic                        i_clk,
    input  logic signed [XLEN:0]        i_a,
    input  logic signed [XLEN:0]        i_b,
    output logic signed [2*XLEN:0]      o_product
);
    always_ff @(posedge i_clk) begin
        o_product <= i_a * i_b;
    end
endmodule: alu_multiplier

module alu_shifter (
    input  logic    [XLEN-1:0]          i_a,
    input  logic    [XLEN-1:0]          i_b,
    input  alu_op_e                     i_op,
    output logic    [XLEN-1:0]          o_shift
);
    localparam int SHAMT_W = $clog2(XLEN);

    always_comb begin
        case (i_op)
            ALU_SLL: o_shift = i_a << i_b[SHAMT_W-1:0];
            ALU_SRL: o_shift = i_a >> i_b[SHAMT_W-1:0];
            ALU_SRA: o_shift = $signed(i_a) >>> i_b[SHAMT_W-1:0];
            default: o_shift = '0;
        endcase
    end
endmodule: alu_shifter

module alu_logic (
    input  logic    [XLEN-1:0]          i_a,
    input  logic    [XLEN-1:0]          i_b,
    input  alu_op_e                     i_op,
    output logic    [XLEN-1:0]          o_logic
);
    always_comb begin
        case (i_op)
            ALU_XOR: o_logic = i_a ^ i_b;
            ALU_OR:  o_logic = i_a | i_b;
            ALU_AND: o_logic = i_a & i_b;
            default: o_logic = '0;
        endcase
    end
endmodule: alu_logic
