/*
 * bru.sv
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
 * 1. the frontend calculates PC+4 always (ofc not when JAL) so no need to calclate it here
 *    just say whether the branch is taken or not
 */

`timescale 1ns/1ps
`default_nettype none

module bru (
    input  logic                           i_clk,
    input  logic                           i_rst_n,

    input  logic                           i_input_valid,
    output logic                           o_input_ready,
    input  logic [XLEN-1:0]                i_thread_id,
    input  branch_operation_e              i_br_op,
    input  logic [32-1:0]                  i_imm,    // sgn extend this to XLEN
    input  logic [VIRT_ADDR_W-1:0]         i_pc,
    input  logic [XLEN-1:0]                i_rs1_data,
    input  logic [XLEN-1:0]                i_rs2_data,

    input  logic                           i_fb_ready,
    output logic [VIRT_ADDR_W-1:0]         o_br_target_addr [NUM_HW_THRDS-1:0],
    output logic                           o_br_taken       [NUM_HW_THRDS-1:0],
    output logic                           o_fb_valid       [NUM_HW_THRDS-1:0]
);
    logic [VIRT_ADDR_W-1:0] w_br_target_a;
    logic [VIRT_ADDR_W-1:0] w_br_target_b;
    logic                   w_br_target_sub;
    logic [VITR_ADDR_W-1:0] w_br_target_sum;
    logic                   w_br_target_carry;

    logic [XLEN-1:0]        w_br_dir_a;
    logic [XLEN-1:0]        w_br_dir_b;
    logic                   w_br_dir_sub;
    logic [XLEN-1:0]        w_br_dir_sum;
    logic                   w_br_dir_carry;

    br_adder br_target_adder (
        .i_a    (w_br_target_a),
        .i_b    (w_br_target_b),
        .i_sub  (w_br_target_sub),
        .o_sum  (w_br_target_sum),
        .o_carry(w_br_target_carry)
    );
    br_adder br_dir_adder (
        .i_a    (w_br_dir_a),
        .i_b    (w_br_dir_b),
        .i_sub  (w_br_dir_sub),
        .o_sum  (w_br_dir_sum),
        .o_carry(w_br_dir_carry)
    );



    /* br_dir---  */
    logic  w_br_dir;
    assign w_br_dir_a   = i_rs1_data;
    assign w_br_dir_b   = i_rs2_data;
    assign w_br_dir_sub = 1'b1;

    always_comb begin
        automatic logic w_signed_lt = (i_rs1_data[XLEN-1] ^ i_rs2_data[XLEN-1])
                                    ? i_rs1_data[XLEN-1]
                                    : ~w_br_dir_carry;
        unique case (i_br_op)
            BRANCH_EQ:   w_br_dir = ~|w_br_dir_sum;
            BRANCH_NE:   w_br_dir = |w_br_dir_sum;
            BRANCH_LT:   w_br_dir = w_signed_lt;
            BRANCH_GE:   w_br_dir = ~w_signed_lt;
            BRANCH_LTU:  w_br_dir = ~w_br_dir_carry;
            BRANCH_GEU:  w_br_dir = w_br_dir_carry;
            BRANCH_JALR: w_br_dir = 1'b1;
            default:     w_br_dir = 1'b0;
        endcase
    end
    /*  ---br_dir  */


    /* br tar---  */
    assign w_br_target_a   = i_br_op == BRANCH_JALR ? i_rs1_data : i_pc;
    assign w_br_target_b   = {{(XLEN-32){i_imm[31]}}, i_imm};
    assign w_br_target_sub = 1'b0;
    /*  ---br tar  */


    /* latching and handskahes---  */
    logic [VIRT_ADDR_W-1:0] r_br_target;
    logic                   r_br_taken;
    logic                   r_fb_valid;
    logic [XLEN-1:0]        r_thread_id;

    assign o_input_ready = ~r_fb_valid | i_fb_ready;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_br_target <= '0;
            r_br_taken  <= 1'b0;
            r_fb_valid  <= 1'b0;
            r_thread_id <= '0;
        end
        else if (o_input_ready) begin
            r_fb_valid <= i_input_valid;

            if (i_input_valid) begin
                r_br_target <= (i_br_op == BRANCH_JALR)
                             ? {w_br_target_sum[VIRT_ADDR_W-1:1], 1'b0}
                             : w_br_target_sum;

                r_br_taken  <= w_br_dir;
                r_thread_id <= i_thread_id;
            end
        end
    end

    always_comb begin
        for (integer i = 0; i < NUM_HW_THRDS; i = i + 1) begin
            o_br_target_addr[i] = r_br_target;
            o_br_taken      [i] = r_br_taken;
            o_fb_valid      [i] = r_fb_valid && (r_thread_id == i);
        end
    end
    /*  ---latching and handskahes */



endmodule: bru


module br_adder (
    input  logic [XLEN-1:0]                i_a,
    input  logic [XLEN-1:0]                i_b,
    input  logic                           i_sub,
    output logic [XLEN-1:0]                o_sum,
    output logic                           o_carry
);
    assign {o_sum, o_carry} = {1'b0, i_a}
                            + (i_b ^ {XLEN{i_sub}})
                            + i_sub;
endmodule: br_adder

`default_nettype wire
