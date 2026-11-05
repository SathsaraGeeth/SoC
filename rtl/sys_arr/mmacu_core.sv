/*
 * mmacu_core.sv
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

import  sys_cnfg_pkg::*;

module mmacu_core (
    input  logic                                    i_clk,
    input  logic                                    i_rst_n,
    input  logic                                    i_clr_n,
    // Compute phase
    input  logic                                    i_start,        // a pulse
    input  logic                                    i_last,         // a pulse
    input  logic [$clog2(M+1)-1:0]                  i_dim,          // compute dimension
    input  logic [M*WIDTH_AB-1:0]                   i_a,
    input  logic [M*WIDTH_AB-1:0]                   i_b,
    input  logic                                    i_ab_valid,
    output logic                                    o_ab_ready,
    // Unload phase
    input  logic [$clog2(M+1)-1:0]                  i_uload_dim,    // a level
    output logic [M*WIDTH_CD-1:0]                   o_d,
    output logic                                    o_d_valid,
    input  logic                                    i_d_ready,
    output logic                                    o_uload_done
);
    /*
    For flow control we use a weak model to faciliate lower latency, higher throughput, and portability
    Preload, Compute, and Unload are independent phases by design - driver should schedule them
    -------------
    1. A/B streams are synced by construct.
    2. A/B and D streams are lockstep-synced. (A/B is synced to D)
        - uArchitectuarly this introduce backpressure to the A/B streams
    */

    logic                       w_gstall_n;
    logic                       w_ab_en;
    logic [M-1:0]               r_uload_mask_vec_dup [M];
    logic [M-1:0]               r_uload_ctr;
    logic                       r_waiting2consume;
    logic [$clog2(M+1)-1:0]     r_uload_dim;
    (* keep = "true" *) logic wn_valid [M][M];

    always_comb begin
        w_gstall_n      = !r_waiting2consume;                                          // backpressure
        o_ab_ready      = w_gstall_n;                                                  // A/B stream is stalled only when globally stalled. (to maintain correctness).
        w_ab_en         = i_ab_valid && o_ab_ready;
        // Signal unload-done when the unload counter reaches the target and there is a valid mask.
        o_uload_done    = (r_uload_ctr == (M'(r_uload_dim) - 1'b1)) && (|r_uload_mask_vec_dup[0]);
    end

    (* keep = "true" *) logic wn_clr_n [M][M];
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int x = 0; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_valid[x][y] <= 1'b0;
                    wn_clr_n[x][y] <= 1'b0;
                end
            end
        end else begin
            wn_valid[0][0] <= w_ab_en;
            wn_clr_n[0][0] <= i_clr_n;
            for (int y = 1; y < M; y++) begin
                wn_valid[0][y] <= wn_valid[0][y-1];
                wn_clr_n[0][y] <= wn_clr_n[0][y-1];
            end
            for (int x = 1; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_valid[x][y] <= wn_valid[x-1][y];
                    wn_clr_n[x][y] <= wn_clr_n[x-1][y];
                end
            end
        end
    end

    // nets
    logic                         wn_start        [M][M];
    logic                         wn_last         [M][M];
    logic [$clog2(M+1)-1:0]       wn_dim          [M][M];
    logic [WIDTH_AB-1:0]          wn_a            [M][M];
    logic [WIDTH_AB-1:0]          wn_b            [M][M];
    logic [WIDTH_CD-1:0]          wn_d            [M][M];
    logic                         wn_done         [M][M];
    logic [WIDTH_AB-1:0]          wn_a_dly        [M];
    logic                         wn_start_a_dly  [M];
    logic                         wn_last_a_dly   [M];
    logic [$clog2(M+1)-1:0]       wn_dim_a_dly    [M];
    logic [WIDTH_AB-1:0]          wn_b_dly        [M];
    logic                         wn_start_b_dly  [M];
    logic                         wn_last_b_dly   [M];
    logic [$clog2(M+1)-1:0]       wn_dim_b_dly    [M];

    //  Unload ---------------
    //  Stage 1 (comb): select wn_done column using i_uload_dim  → w_uload_mask_vec
    //  Stage 1 (reg) : register the mask                        → r_uload_mask_vec
    //  Stage 2 (reg) : use r_uload_mask_vec to mux wn_d → o_d

    logic [M-1:0]                w_uload_mask_vec;
    logic                        r_d_ready;
    logic [$clog2(M+1)-1:0]      r_uload_dim_pipe;

    // Stage 1: Pipeline the incoming dimension to break the FIFO RAM async-read path
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !i_clr_n) begin
            r_uload_dim_pipe <= '0;
        end else begin
            r_uload_dim_pipe <= i_uload_dim;
        end
    end

    // Use the pipelined dimension to select the done flag
    always_comb begin
        w_uload_mask_vec = '0;
        for (int k = 0; k < M; k++) begin
            w_uload_mask_vec[k] = wn_done[k][r_uload_dim_pipe-1];
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !i_clr_n) begin
            for (int j = 0; j < M; j++) begin
                r_uload_mask_vec_dup[j] <= '0;
            end
            r_d_ready        <= 1'b0;
            r_uload_dim      <= '0;
        end else begin
            for (int j = 0; j < M; j++) begin
                r_uload_mask_vec_dup[j] <= w_uload_mask_vec;
            end
            r_d_ready        <= i_d_ready;
            if (i_d_ready) begin
                r_uload_dim  <= r_uload_dim_pipe;
            end
        end
    end

    // Pre-masking the data locally to break the huge MUX tree into an OR tree
    logic [M*WIDTH_CD-1:0] w_masked_d [M];
    always_comb begin
        for (int m = 0; m < M; m++) begin
            for (int j = 0; j < M; j++) begin
                w_masked_d[m][j*WIDTH_CD +: WIDTH_CD] = r_uload_mask_vec_dup[j][m] ? wn_d[m][j] : '0;
            end
        end
    end

    // Combinational OR-tree to merge all rows
    logic [M*WIDTH_CD-1:0] w_merged_d;
    always_comb begin
        w_merged_d = '0;
        for (int m = 0; m < M; m++) begin
            w_merged_d |= w_masked_d[m];
        end
    end

    // Stage 2
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !i_clr_n) begin
            o_d               <= '0;
            o_d_valid         <= 1'b0;
            r_uload_ctr       <= '0;
            r_waiting2consume <= 1'b0;
        end else begin
            r_waiting2consume <= 1'b0;
            o_d_valid         <= |r_uload_mask_vec_dup[0];
            
            if (|r_uload_mask_vec_dup[0]) begin
                // Always capture the merged output when available.
                o_d <= w_merged_d;
                // Advance unload counter only when consumer is ready.
                if (i_d_ready) begin
                    if (r_uload_ctr == (M'(r_uload_dim) - 1'b1))
                        r_uload_ctr <= '0;
                    else
                        r_uload_ctr <= r_uload_ctr + 1'b1;
                end else begin
                    r_waiting2consume <= 1'b1;
                end
            end
        end
    end
    // ----------------

    // * ---------------
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : ROW
            for (j = 0; j < M; j++) begin : COL
                if (MAC_T == MAC20I_STATIC) begin
                    mac20i #(WIDTH_AB, WIDTH_CD, M) u_mac (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_start   (wn_start[i][j]),
                        .i_last    (wn_last[i][j]),
                        .i_dim     (wn_dim[i][j]),
                        .i_a       (wn_a[i][j]),
                        .i_b       (wn_b[i][j]),
                        .o_done    (wn_done[i][j]),
                        .o_d       (wn_d[i][j])
                    );
                end else if (MAC_T == MACFP8_STATIC) begin
                    mac_fp8_fp8_fp8_61 u_mac (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_start   (wn_start[i][j]),
                        .i_last    (wn_last[i][j]),
                        .i_dim     (wn_dim[i][j]),
                        .i_a       (wn_a[i][j]),
                        .i_b       (wn_b[i][j]),
                        .o_done    (wn_done[i][j]),
                        .o_d       (wn_d[i][j])
                    );
                end
                if (j == 0) begin : GEN_DELAY_A
                    delayed_pipe #(.WIDTH (WIDTH_AB+1+1+$clog2(M+1)), .DEPTH (i+1)) u_delay_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (1'b1),
                        .i_clr_n   (i_clr_n),
                        .i_in      ({i_a[i*WIDTH_AB +: WIDTH_AB], i_start, i_last, i_dim}),
                        .o_out     ({wn_a_dly[i], wn_start_a_dly[i], wn_last_a_dly[i], wn_dim_a_dly[i]})
                    );
                    register #(WIDTH_AB+1+1+$clog2(M+1)) u_shift_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    ({wn_a_dly[i], wn_start_a_dly[i], wn_last_a_dly[i], wn_dim_a_dly[i]}),
                        .o_data    ({wn_a[i][j], wn_start[i][j], wn_last[i][j], wn_dim[i][j]})
                    );
                end else begin : GEN_SHIFT_A
                    register #(WIDTH_AB+1+1+$clog2(M+1)) u_shift_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    ({wn_a[i][j-1], wn_start[i][j-1], wn_last[i][j-1], wn_dim[i][j-1]}),
                        .o_data    ({wn_a[i][j], wn_start[i][j], wn_last[i][j], wn_dim[i][j]})
                    );
                end
                if (i == 0) begin : GEN_DELAY_B
                    delayed_pipe #(.WIDTH (WIDTH_AB+1+1), .DEPTH (j+1)) u_delay_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (1'b1),
                        .i_clr_n   (i_clr_n),
                        .i_in      ({i_b[j*WIDTH_AB +: WIDTH_AB], i_start, i_last}),
                        .o_out     ({wn_b_dly[j], wn_start_b_dly[j], wn_last_b_dly[j]})
                    );
                    register #(WIDTH_AB) u_shift_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    (wn_b_dly[j]),
                        .o_data    (wn_b[i][j])
                    );
                end else begin : GEN_SHIFT_B
                    register #(WIDTH_AB) u_shift_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j]),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    (wn_b[i-1][j]),
                        .o_data    (wn_b[i][j])
                    );
                end
            end
        end
    endgenerate
    // ----------------

endmodule: mmacu_core
