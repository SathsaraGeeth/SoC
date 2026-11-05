/*
 * sys_address_generator.sv
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
 * 1. Generates vector granularity addresses for one A, B, or D address
 */


`timescale 1ns/1ps
`default_nettype none

import sys_cnfg_pkg::*;

module sys_address_generator #(
    parameter bit IS_WB = 1'b0,
    parameter bit IS_B  = 1'b0
) (
    input  logic                                          i_clk,
    input  logic                                          i_rst_n,
    input  logic                                          i_start,
    input  logic [XLEN-1:0]                               i_tid,
    input  logic [VIR_ADDR_W-1:0]                         i_base_addr,
    input  logic [TILE_W-1:0]                             i_a_tiles,
    input  logic [TILE_W-1:0]                             i_b_tiles,
    input  logic                                          i_dense,
    input  logic                                          i_cmd_start,
    input  logic                                          i_cmd_last,
    input  mac_t                                          i_mac_type,

    input  logic                                          i_addr_enq_ready,
    output logic                                          o_addr_enq_valid,
    output logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] o_addr_enq_data,
    output logic                                          o_done
);
    localparam int BEAT_W = $clog2(M);
    typedef enum logic {IDLE, GEN} state_e;

    state_e                     r_state;
    logic [TILE_W-1:0]          r_a_tiles_limit;
    logic [TILE_W-1:0]          r_b_tiles_limit;
    logic [TILE_W-1:0]          r_r_tiles_limit;
    logic [TILE_W-1:0]          r_a_idx;
    logic [TILE_W-1:0]          r_b_idx;
    logic [TILE_W-1:0]          r_q_idx;
    logic [BEAT_W-1:0]          r_beat;
    logic [VIR_ADDR_W-1:0]      r_base_addr;
    logic [XLEN-1:0]            r_tid;
    logic                       r_dense;
    logic                       r_cmd_start;
    logic                       r_cmd_last;
    mac_t                       r_mac_type;

    logic                       w_fire;
    logic                       w_skip_reused;
    logic                       w_last_beat;
    logic                       w_last_entry;
    logic                       w_is_start;
    logic                       w_is_last;
    logic                       w_is_end;
    logic [VIR_ADDR_W-1:0]      w_addr;
    logic [ADDR_FLAGS_W-1:0]    w_flags;

    assign w_skip_reused    = r_dense && !IS_WB &&
                              ((!IS_B && (r_b_idx != '0)) ||
                               (IS_B && (r_a_idx != '0) && (r_b_idx == '0)));
    assign o_addr_enq_valid = (r_state == GEN);
    assign w_fire           = o_addr_enq_valid && i_addr_enq_ready;
    assign w_last_beat      = (r_beat == BEAT_W'(M-1));
    assign w_is_start       = r_dense ? (r_q_idx == '0) : r_cmd_start;
    assign w_is_last        = r_dense ? (r_q_idx + 1'b1 == r_r_tiles_limit) : r_cmd_last;
    assign w_is_end         = (r_dense || r_cmd_last) &&
                              (r_a_idx + 1'b1 == r_a_tiles_limit) &&
                              (r_b_idx + 1'b1 == r_b_tiles_limit) &&
                              (r_q_idx + 1'b1 == r_r_tiles_limit) &&
                              w_last_beat;
    assign w_last_entry     = IS_WB
                            ? ((r_a_idx + 1'b1 == r_a_tiles_limit) &&
                               (r_b_idx + 1'b1 == r_b_tiles_limit) && w_last_beat)
                            : ((r_a_idx + 1'b1 == r_a_tiles_limit) &&
                               (r_b_idx + 1'b1 == r_b_tiles_limit) &&
                               (r_q_idx + 1'b1 == r_r_tiles_limit) && w_last_beat);

    always_comb begin
        w_addr = '0;
        w_flags = ADDR_FLAGS_NONE;

        if (IS_WB) begin
            w_addr = calc_d_addr(r_base_addr, r_a_idx, r_beat, r_b_tiles_limit, r_b_idx);
        end else begin
            w_addr  = IS_B
                    ? calc_b_addr(r_base_addr, r_q_idx, r_beat, r_b_tiles_limit, r_b_idx)
                    : calc_a_addr(r_base_addr, r_q_idx, r_beat, r_a_tiles_limit, r_a_idx);
            w_flags = w_is_end ? ADDR_FLAGS_END
                    : (r_beat == '0) ? {1'b0, w_is_last, w_is_start}
                    : ADDR_FLAGS_CONTINUE;
        end

        o_addr_enq_data = {w_skip_reused, r_dense, w_addr, r_tid, r_mac_type, w_flags};
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state         <= IDLE;
            r_a_tiles_limit <= '0;
            r_b_tiles_limit <= '0;
            r_r_tiles_limit <= '0;
            r_a_idx         <= '0;
            r_b_idx         <= '0;
            r_q_idx         <= '0;
            r_beat          <= '0;
            r_base_addr     <= '0;
            r_tid           <= '0;
            r_dense         <= 1'b0;
            r_cmd_start     <= 1'b0;
            r_cmd_last      <= 1'b0;
            r_mac_type      <= MAC20I;
            o_done          <= 1'b0;
        end else begin
            o_done <= 1'b0;

            case (r_state)
                IDLE: begin
                    if (i_start) begin
                        r_state         <= GEN;
                        r_a_tiles_limit <= i_a_tiles;
                        r_b_tiles_limit <= i_b_tiles;
                        r_r_tiles_limit <= i_a_tiles;
                        r_a_idx         <= '0;
                        r_b_idx         <= '0;
                        r_q_idx         <= '0;
                        r_beat          <= '0;
                        r_base_addr     <= i_base_addr;
                        r_tid           <= i_tid;
                        r_dense         <= i_dense;
                        r_cmd_start     <= i_cmd_start;
                        r_cmd_last      <= i_cmd_last;
                        r_mac_type      <= i_mac_type;
                    end
                end

                GEN: begin
                    if (w_fire) begin
                        if (w_last_entry) begin
                            r_state <= IDLE;
                            o_done  <= 1'b1;
                        end else if (!w_last_beat) begin
                            r_beat <= r_beat + 1'b1;
                        end else begin
                            r_beat <= '0;
                            if (IS_WB) begin
                                if (r_b_idx + 1'b1 == r_b_tiles_limit) begin
                                    r_b_idx <= '0;
                                    r_a_idx <= r_a_idx + 1'b1;
                                end else begin
                                    r_b_idx <= r_b_idx + 1'b1;
                                end
                            end else if (r_q_idx + 1'b1 == r_r_tiles_limit) begin
                                r_q_idx <= '0;
                                if (r_b_idx + 1'b1 == r_b_tiles_limit) begin
                                    r_b_idx <= '0;
                                    r_a_idx <= r_a_idx + 1'b1;
                                end else begin
                                    r_b_idx <= r_b_idx + 1'b1;
                                end
                            end else begin
                                r_q_idx <= r_q_idx + 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule: sys_address_generator
