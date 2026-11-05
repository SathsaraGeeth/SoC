/*
 * mmacu.sv
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

module mmacu (
        input  logic                    i_clk,
        input  logic                    i_rst_n,

        input  logic                    i_start_block,    // start block marker
        input  logic                    i_last_block,     // last block marker
        input  logic                    i_break,    // final beat of final block
        input  logic [$clog2(M+1)-1:0]  i_dim,

        input  logic [M*WIDTH_AB-1:0]   i_a,
        input  logic [M*WIDTH_AB-1:0]   i_b,
        output logic [M*WIDTH_CD-1:0]   o_d,

        input  logic                    i_ab_valid,
        input  logic                    i_d_ready,

        output logic                    o_ab_ready,
        output logic                    o_d_valid
);      
        typedef enum logic {
            IDLE,
            FLUSHING
        } state_t;

        logic                           w_uload_done;
        logic                           w_d_valid;
        logic                           w_ab_ready;

        state_t s_this, s_next, s_last;

        logic w_start_flush_ctr;
        logic w_done_flush;
        logic w_clr_n;
        
        assign o_d_valid  = w_d_valid;
        assign o_ab_ready = w_ab_ready && ~ (s_this == FLUSHING) ;
        
        logic w_flush_pulse;
        assign w_flush_pulse = (s_this == FLUSHING && s_last == IDLE);

        mmacu_core u_mmacu_core (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_clr_n(w_clr_n),
                .i_start(i_start_block | w_flush_pulse),
                .i_last(i_last_block | w_flush_pulse),
                .i_dim(i_dim),
                .i_a(i_a),
                .i_b(i_b),
                .i_ab_valid(i_ab_valid | s_this == FLUSHING),
                .o_ab_ready(w_ab_ready),
                .i_uload_dim(i_dim),
                .o_d(o_d),
                .o_d_valid(w_d_valid),
                .i_d_ready(i_d_ready),
                .o_uload_done(w_uload_done)
        );

        always_ff @(posedge i_clk or negedge i_rst_n) begin
            if (!i_rst_n) begin
                s_this <= IDLE;
                s_last <= IDLE;
            end else begin
                s_this <= s_next;
                s_last <= s_this;
            end
        end

        always_comb begin
            s_next = s_this;
            w_start_flush_ctr = 1'b0;
            w_clr_n  = 1'b1;
            case (s_this)
                IDLE: begin
                    if (i_break && i_ab_valid && o_ab_ready) begin
                        s_next = FLUSHING;
                        w_start_flush_ctr = 1'b1;
                    end
                end
                FLUSHING: begin
                    if (w_done_flush) begin
                        s_next = IDLE;
                        w_clr_n = 1'b0;
                    end
                end
            endcase
        end

        localparam int FLUSH_CTR_W = $clog2(10*M + L + 1);

        ctr #(
            .WIDTH  (FLUSH_CTR_W)
        ) ctr_flush (
            .i_clk    (i_clk),
            .i_rst_n  (i_rst_n),
            .i_start  (w_start_flush_ctr),
            .i_en     ((i_ab_valid | s_this == FLUSHING) && w_ab_ready),
            .i_target (FLUSH_CTR_W'(10*i_dim+L-1)),
            .o_done   (w_done_flush)
        );
endmodule: mmacu
