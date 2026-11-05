/*
 * frontend.sv
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
 * 1. Performace targets:
 *    a. at least one istruction is always valid at `o_decoded_instr NUM_HW_THRDS-1:0]
 *    b. utilization of the memory port is around 50% (much lower or much higer both bad) over the runtime
 */

`timescale 1ns/1ps
`default_nettype none

import isa_pkg::*;
import memory_pkg::*;
import core_pkg::*;
import frontend_pkg::*;

module frontend #(
    parameter logic [VIR_ADDR_W-1:0] RESET_VEC = '0
) (
    input  logic                            i_clk,
    input  logic                            i_rst_n,

    input  logic                            i_req_instr_ready,
    output logic                            o_req_instr_valid,
    output mem_req_t                        o_req_instr,
    output logic                            o_resp_instr_ready,
    input  logic                            i_resp_instr_valid,
    input  mem_resp_t                       i_resp_instr,
    input  logic                            i_resp_page_msg_instr_valid,
    output logic                            o_resp_page_msg_instr_ready,
    input  mem_page_resp_t                  i_resp_page_msg_instr,

    output logic                            o_decoded_instr_valid        [NUM_HW_THRDS-1:0],
    input  logic                            i_decoded_instr_ready        [NUM_HW_THRDS-1:0],
    output decoded_instr_t                  o_decoded_instr              [NUM_HW_THRDS-1:0],

    input  logic                            i_irq_timer                  [NUM_HW_THRDS-1:0],
    input  logic                            i_irq_wake                   [NUM_HW_THRDS-1:0],

    input  logic                            i_data_page_fault            [NUM_HW_THRDS-1:0],

    input  logic                            i_redirect_valid             [NUM_HW_THRDS-1:0],
    input  logic [VIR_ADDR_W-1:0]           i_redirect_pc                [NUM_HW_THRDS-1:0]
);

    /* *---  */
    logic [INST_W-1:0]          w_decoder_instr;
    logic [VIR_ADDR_W-1:0]      w_decoder_pc;
    decoded_instr_t             w_decoder_decoded;

    frontend_decoder decoder (
        .i_instr  (w_decoder_instr),
        .i_pc     (w_decoder_pc),
        .o_decoded(w_decoder_decoded)
    );

    fe_thrd_state_t  r_thrd_state [NUM_HW_THRDS-1:0];
    /*  ---* */


    /*
     * 1. choose a winner -> calculating npc -> fetch
     * 2. choose a winner -> decode
     * 3. handling wakeup and puting to sleep
     * 4. handling redirection
     * 5. response handling & fault handling
     * 6. presenting work to backend and handling backend feedback
     * 7. handling timer irq
     * 8. handling page failt fron data - only need to increase the epoch backend do the dropping
     *    younger istructions
     * 9. priv mode handling
     */


    /* p0:request pipe---  */

    /*
     * s0: if there is possible candidate choose of with
     * round robin arbitration
     * waiting_for_fb, waiting_for_mem, waiting_for_consume, waiting_for_wakeup
     * unqualify for contending
     * also dont choose already prefetched ones
     */

    /* s0:Choose a winner---  */
    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s1_last_winner;
    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s1_winner;
    logic                             w_p0_s1_valid;

    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s0_last_winner;
    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s0_winner;
    logic                             w_p0_s0_valid;
    logic                             w_p0_s0_winner_found;

    always_comb begin
        w_p0_s0_winner = '0;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic int thrd = (int'(w_p0_s1_last_winner) + i + 1) % NUM_HW_THRDS;
            if (!r_thrd_state[thrd].waiting_for_fb &&
                !r_thrd_state[thrd].waiting_for_consume &&
                !r_thrd_state[thrd].waiting_for_mem &&
                !r_thrd_state[thrd].waiting_for_wakeup &&
                !r_thrd_state[thrd].is_prefetched_valid &&
                !r_thrd_state[thrd].is_npc_valid &&
                 r_thrd_state[thrd].is_decoded) begin
                
                w_p0_s0_winner_found = 1'b1;
                w_p0_s0_winner       = $clog2(NUM_HW_THRDS)'(thrd);
                break;
            end
        end
        w_p0_s0_last_winner = w_p0_s2_last_winner;
        w_p0_s0_valid       = w_p0_s3_valid;
    end

    always_ff @(posedge i_clk) begin: s0_pr_s1
        if (!i_rst_n) begin
            w_p0_s1_last_winner <= '0;
            w_p0_s1_winner      <= '0;
            w_p0_s1_valid       <= 1'b0;
        end else begin
            w_p0_s1_last_winner <= w_p0_s0_last_winner;
            w_p0_s1_winner      <= w_p0_s0_winner;
            w_p0_s1_valid       <= w_p0_s0_winner_found;
        end
    end: s0_pr_s1
    /*  ---s0 */

    /* s1---  */
    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s2_last_winner;
    logic [$clog2(NUM_HW_THRDS)-1:0]  w_p0_s2_winner;
    logic                             w_p0_s2_valid;

    logic [VIR_ADDR_W-1:0]            w_p0_s1_npc;

    always_comb begin: npc_calc
        automatic decoded_instr_t        decoded_instr = r_thrd_state[w_p0_s1_winner].instr.decoded;
        automatic logic [VIR_ADDR_W-1:0] pc            = r_thrd_state[w_p0_s1_winner].pc;
        automatic logic                  is_jump_abs   = decoded_instr.fu         == FU_BRANCH
                                                       & decoded_instr.fu_ctrl.op == BRANCH_JAL;
        automatic logic [VIR_ADDR_W-1:0] offset        = is_jump_abs ? decoded_instr.operands.imm 
                                                       : VIR_ADDR_W'd(4);

        w_p0_s1_npc          = pc + offset;
    end: npc_calc

    always_ff @(posedge i_clk) begin: s1_pr_s2
        if (!i_rst_n) begin
            w_p0_s2_last_winner                       <= '0;
            w_p0_s2_winner                            <= '0;
            w_p0_s2_valid                             <= 1'b0;
            r_thrd_state[w_p0_s1_winner].npc          <= '0;
            r_thrd_state[w_p0_s1_winner].is_npc_valid <= '0;
        end else if (w_p0_s1_valid) begin
            w_p0_s2_last_winner                       <= w_p0_s1_last_winner;
            w_p0_s2_winner                            <= w_p0_s1_winner;
            w_p0_s2_valid                             <= w_p0_s1_valid;
            r_thrd_state[w_p0_s1_winner].npc          <= w_p0_s1_npc;
            r_thrd_state[w_p0_s1_winner].is_npc_valid <= 1'b1;
        end
    end: s1_pr_s2
    /*  ---s1 */

    /* s2---  */
    logic                                   w_p0_s3_valid;

    mem_req_t                               w_p0_s2_req_instr;

    always_comb begin: fetch_req
        w_p0_s2_req_instr = {   .we   (1'b0),
                                .thrd (w_p0_s2_winner),
                                .is_lr(1'b0),
                                .is_sc(1'b0),
                                .addr (r_thrd_state[w_p0_s2_winner].npc),
                                .wstrb('0),
                                .wdata('0),
                                .priv (r_thrd_state[w_p0_s2_winner].priv_mode)}
    end: fetch_req

    always_ff @(posedge i_clk) begin: s2_pr_s3
        if (!i_rst_n) begin
            w_p0_s3_valid     <= 1'b0;
            o_req_instr_valid <= 1'b0;
            o_req_instr       <= '0;
        end else if (w_p0_s2_valid && i_req_instr_ready) begin
            w_p0_s3_valid     <= 1'b1;
            o_req_instr_valid <= 1'b1;
            o_req_instr       <= w_p0_s2_req_instr;
        end else begin
            w_p0_s3_valid     <= 1'b0;
            o_req_instr_valid <= 1'b0;
            o_req_instr       <= '0;
        end
    end: s2_pr_s3
    /*  ---s2 */

    /*  ---p0 */

    /* p1:decode pipe---  */




    /*  ---p1 */





typedef struct packed {
    logic                   waiting_for_fb;
    logic                   waiting_for_consume;
    logic                   waiting_for_mem;
    logic                   waiting_for_wakeup;

    priv_t                  priv_mode;
    event_t                 events;
    event_t                 pending_events;

    logic [XLEN-1:0]        pc;
    instr_t                 instr;
    logic                   is_decoded;
    logic                   is_pc_valid;
    logic                   is_instr_valid;

    logic [XLEN-1:0]        npc;
    raw_instr_t             prefetched_instr;
    logic                   is_npc_valid;
    logic                   is_prefetched_valid;
} fe_thrd_state_t;

endmodule: frontend

module fe_seq_adder (
    input  logic [VIR_ADDR_W-1:0] i_pc,
    input  logic [VIR_ADDR_W-1:0] i_off,
    output logic [VIR_ADDR_W-1:0] o_pc
);
    assign o_pc = i_pc + i_off;
endmodule: fe_seq_adder

`default_nettype wire
