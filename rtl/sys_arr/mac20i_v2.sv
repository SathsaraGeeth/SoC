`timescale 1ns/1ps
`default_nettype none

 import sys_cnfg_pkg::*;

module mac20i_v2 #(parameter WIDTH_AB = 8, parameter WIDTH_CD = 8, parameter M = 4)(
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_en,
    input  logic                    i_clr_n,
    input  logic                    i_start,
    input  logic                    i_last,
    input  logic [WIDTH_AB-1:0]     i_a,
    input  logic [WIDTH_AB-1:0]     i_b,
    output logic                    o_done,
    output logic [WIDTH_CD-1:0]     o_d
);  
    localparam int INTRL_W = 32;
    ///////////////////////////////////////////////
    // Stage 0 (colapsed) >>>
    logic [WIDTH_AB-1:0] w_s1_a;
    logic [WIDTH_AB-1:0] w_s1_b;
    logic [WIDTH_CD-1:0] w_s1_c;
    logic                w_s1_start;
    logic [31:0]         w_s1_l0_acc_in;
    logic [31:0]         w_s1_l1_acc_in;
    logic                w_s1_lane;
    ///////////////////////////////////////////////
    assign w_s1_a     = i_a;
    assign w_s1_b     = i_b;
    assign w_s1_c     = '0;
    assign w_s1_start = i_start;
    ///////////////////////////////////////////////
    // Stage 1 >>>
    logic                   w_s2_start;
    logic [31:0]            w_s2_l0_acc;
    logic [31:0]            w_s2_l1_acc;
    logic                   w_s2_lane;
    logic [31:0]            w_s2_mulr;
    logic [31:0]            w_s2_l0_add;
    logic [31:0]            w_s2_l1_add;
    ///////////////////////////////////////////////
    logic [2*WIDTH_AB-1:0]  w_mul_res;

    assign w_s2_mulr = 32'($signed(w_mul_res));
    assign w_s1_lane = (i_en && w_s1_start) ? (w_s2_lane ^ 1'b1) : w_s2_lane;

    mul_lat1 #(.IN_WIDTH(WIDTH_AB)) pr_s1_mulr(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_clr_n(i_clr_n),
        .i_en(i_en),
        .i_data0(w_s1_a),
        .i_data1(w_s1_b),
        .o_data(w_mul_res)
    );
    register #(.WIDTH(1)) pr_s1_lane (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_clr_n(i_clr_n),
        .i_en(i_en),
        .i_data(w_s1_lane),
        .o_data(w_s2_lane)
    );
    mux2 #(.WIDTH(32)) mux_l0_acc_src(
        .i_data0(w_s2_l0_add),
        .i_data1(32'(w_s1_c)),
        .i_sel(w_s1_start && (w_s1_lane == 1'b0)),
        .o_data(w_s1_l0_acc_in)
    );
    mux2 #(.WIDTH(32)) mux_l1_acc_src(
        .i_data0(w_s2_l1_add),
        .i_data1(32'(w_s1_c)),
        .i_sel(w_s1_start && (w_s1_lane == 1'b1)),
        .o_data(w_s1_l1_acc_in)
    );
    register #(.WIDTH(32)) pr_s1_l0_acc (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_clr_n(i_clr_n),
        .i_en(i_en),
        .i_data(w_s1_l0_acc_in),
        .o_data(w_s2_l0_acc)
    );
    register #(.WIDTH(32)) pr_s1_l1_acc (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_clr_n(i_clr_n),
        .i_en(i_en),
        .i_data(w_s1_l1_acc_in),
        .o_data(w_s2_l1_acc)
    );
    register #(.WIDTH(1)) pr_s1_start(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_clr_n(i_clr_n),
        .i_en(i_en),
        .i_data(w_s1_start),
        .o_data(w_s2_start)
    );

    ///////////////////////////////////////////////
    // Stage 2 >>>
    ///////////////////////////////////////////////
    logic [31:0] w_add_acc_in;
    logic [31:0] w_add_result;
    logic [31:0] w_s2_d;

    assign w_add_acc_in = (w_s2_lane == 1'b0) ? w_s2_l0_acc : w_s2_l1_acc;
    assign w_add_result = w_s2_mulr + w_add_acc_in;
    assign w_s2_l0_add = (w_s2_lane == 1'b0) ? w_add_result : w_s2_l0_acc;
    assign w_s2_l1_add = (w_s2_lane == 1'b1) ? w_add_result : w_s2_l1_acc;

    mux2 #(.WIDTH(32)) mux_output(
        .i_data0(w_s2_l0_acc),
        .i_data1(w_s2_l1_acc),
        .i_sel(r_done_bank[r_done_bank_rd]),
        .o_data(w_s2_d)
    );

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_d <= '0;
        end else if (!i_clr_n) begin
            o_d <= '0;
        end else if (i_en && o_done) begin
            o_d <= w_s2_d[WIDTH_CD-1:0];
        end
    end

    ///////////////////////////////////////////////
    
    logic        r_done_bank [2];
    logic        r_done_bank_rd;
    logic        r_done_bank_wr;
    logic [1:0]  r_done_bank_count;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !i_clr_n) begin
            r_done_bank_rd    <= 1'b0;
            r_done_bank_wr    <= 1'b0;
            r_done_bank_count <= '0;
            r_done_bank[0]    <= 1'b0;
            r_done_bank[1]    <= 1'b0;
        end else if (i_en) begin
            case ({i_last, o_done})
                2'b10: begin
                    r_done_bank[r_done_bank_wr] <= (i_start && i_last) ? w_s1_lane : w_s2_lane;
                    r_done_bank_wr <= ~r_done_bank_wr;
                    r_done_bank_count <= r_done_bank_count + 1'b1;
                end
                2'b01: begin
                    r_done_bank_rd <= ~r_done_bank_rd;
                    r_done_bank_count <= r_done_bank_count - 1'b1;
                end
                2'b11: begin
                    r_done_bank[r_done_bank_wr] <= (i_start && i_last) ? w_s1_lane : w_s2_lane;
                    r_done_bank_wr <= ~r_done_bank_wr;
                    r_done_bank_rd <= ~r_done_bank_rd;
                end
                default: begin end
            endcase
        end
    end

    ///////////////////////////////////////////////
    logic [M-1:0] r_last_pipe;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_last_pipe <= '0;
            o_done      <= 1'b0;
        end else if (!i_clr_n) begin
            r_last_pipe <= '0;
            o_done      <= 1'b0;
        end else if (i_en) begin
            r_last_pipe <= {r_last_pipe[M-2:0], i_last};
            o_done      <= r_last_pipe[M-1];
        end
    end
endmodule: mac20i_v2
