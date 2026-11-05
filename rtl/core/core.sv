`timescale 1ns/1ps
`default_nettype none

import isa_pkg::*;
import core_pkg::*;
import memory_pkg::*;

module core #(
    parameter logic [VIR_ADDR_W-1:0] RESET_VEC = '0
) (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic [XLEN-1:0]                 i_thrd_id_vec               [NUM_HW_THRDS-1:0],
    input  logic [NUM_HW_THRDS-1:0]         i_wake_intr_vec,
    input  logic [NUM_HW_THRDS-1:0]         i_irq_timer_vec,

    input  logic                            i_req_instr_ready,
    output logic [VIR_ADDR_W-1:0]           o_req_instr_addr,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_req_instr_thrd_id,
    output logic [PRIV_MODE_W-1:0]          o_req_instr_priv,
    output logic                            o_req_instr_valid,
    output logic                            o_resp_instr_ready,
    input  logic [XLEN-1:0]                 i_resp_instr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_resp_instr_thrd_id,
    input  logic                            i_resp_instr_valid,
    input  logic                            i_page_msg_instr_valid,
    input  logic [PAGE_MSG_W-1:0]           i_page_msg_instr,
    output logic                            o_page_msg_instr_ready,

    input  logic                            i_req_data_ready,
    output logic [VIR_ADDR_W-1:0]           o_req_data_addr,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_req_data_thrd_id,
    output logic [PRIV_MODE_W-1:0]          o_req_data_priv,
    output logic                            o_req_data_rw,
    output logic                            o_req_data_lq,
    output logic                            o_req_data_sc,
    output logic [XLEN/8-1:0]               o_req_data_wstrb,
    output logic [XLEN-1:0]                 o_req_data_wdata,
    output logic                            o_req_data_valid,
    output logic                            o_resp_data_ready,
    input  logic [XLEN-1:0]                 i_resp_data_rdata,
    input  logic                            i_resp_data_sc_ok,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_resp_data_thrd_id,
    input  logic                            i_resp_data_valid,
    input  logic                            i_page_msg_data_valid,
    input  logic [PAGE_MSG_W-1:0]           i_page_msg_data,
    output logic                            o_page_msg_data_ready,
    output logic                            o_page_msg_valid,
    output logic [PAGE_MSG_W-1:0]           o_page_msg,
    input  logic                            i_page_msg_ready
);
    typedef struct packed {
        logic [1:0]                         valid;
        issue_instr_t [1:0]                 instr;
    } alu_fifo_entry_t;
    /**--- */
    logic [INST_W-1:0]                      w_decoder_instr;
    decoded_instr_t                         w_decoder_decoded_instr;
    logic [INST_W-1:0]                      w_decoder_instr_1;
    decoded_instr_t                         w_decoder_decoded_instr_1;

    logic                                   w_regfile_we;
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs1_addr;
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs2_addr;
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs3_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_regfile_rthrd_id;
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rd_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_regfile_wthrd_id;
    logic [XLEN-1:0]                        w_regfile_rd_wdata;
    logic [XLEN-1:0]                        w_regfile_rs1_data;
    logic [XLEN-1:0]                        w_regfile_rs2_data;
    logic [XLEN-1:0]                        w_regfile_rs3_data;
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs1_addr_vec    [NUM_HW_THRDS-1:0];
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs2_addr_vec    [NUM_HW_THRDS-1:0];
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rs3_addr_vec    [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_regfile_rs1_data_vec    [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_regfile_rs2_data_vec    [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_regfile_rs3_data_vec    [NUM_HW_THRDS-1:0];
    logic                                   w_regfile_we_vec          [NUM_HW_THRDS-1:0];
    logic [$clog2(REG_COUNT)-1:0]           w_regfile_rd_addr_vec     [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_regfile_rd_wdata_vec    [NUM_HW_THRDS-1:0];

    issue_instr_t                           w_ififo_head_data;
    issue_instr_t                           w_ififo_head_data_vec     [NUM_HW_THRDS-1:0];
    logic                                   w_ififo_deq_valid;
    logic                                   w_ififo_deq_valid_vec     [NUM_HW_THRDS-1:0];
    logic                                   w_ififo_deq_ready;
    logic                                   w_ififo_deq_ready_vec     [NUM_HW_THRDS-1:0];
    issue_instr_t                           w_ififo_enq_data_vec      [NUM_HW_THRDS-1:0];
    logic                                   w_ififo_enq_valid_vec     [NUM_HW_THRDS-1:0];
    logic                                   w_ififo_enq_ready_vec     [NUM_HW_THRDS-1:0];
    logic [$clog2(ISSUE_Q_DEPTH+1)-1:0]     w_ififo_level             [NUM_HW_THRDS-1:0];
    logic                                   w_ififo_clr_n             [NUM_HW_THRDS-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        r_fu_last_thrd_id        [FU_COUNT-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_fu_winner_thrd_id      [FU_COUNT-1:0];
    logic                                   w_fu_winner_valid        [FU_COUNT-1:0];
    logic                                   w_fu_fifo_enq_fire       [FU_COUNT-1:0];
    issue_instr_t                           r_rob_instr              [NUM_HW_THRDS-1:0];
    logic                                   r_rob_valid              [NUM_HW_THRDS-1:0];
    logic                                   r_rob_dispatched         [NUM_HW_THRDS-1:0];
    logic                                   r_rob_immediate_done     [NUM_HW_THRDS-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        r_commit_last_thrd_id;
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_commit_thrd_id;
    logic                                   w_commit_found;
    logic                                   w_fast_commit_vec        [NUM_HW_THRDS-1:0];
    logic                                   w_commit_valid_vec       [NUM_HW_THRDS-1:0];
    logic                                   r_lsu_resp_valid_vec      [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        r_lsu_resp_rdata_vec      [NUM_HW_THRDS-1:0];
    logic                                   r_lsu_resp_sc_ok_vec      [NUM_HW_THRDS-1:0];
    logic                                   r_lsu_pf_valid_vec        [NUM_HW_THRDS-1:0];
    logic                                   r_lsu_request_pending_vec [NUM_HW_THRDS-1:0];
    logic                                   r_lsu_resp_valid;
    logic                                   r_lsu_pf_valid;
    logic                                   r_lsu_request_pending;
    issue_instr_t                           w_fu_fifo_head_data      [FU_COUNT-1:0];
    logic                                   w_fu_fifo_deq_valid      [FU_COUNT-1:0];
    logic                                   w_fu_fifo_deq_ready      [FU_COUNT-1:0];
    issue_instr_t                           w_fu_fifo_enq_data       [FU_COUNT-1:0];
    logic                                   w_fu_fifo_enq_valid      [FU_COUNT-1:0];
    logic                                   w_fu_fifo_enq_ready      [FU_COUNT-1:0];
    logic [$clog2(FU_Q_DEPTH+1)-1:0]        w_fu_fifo_level          [FU_COUNT-1:0];

    issue_instr_t                           w_alu_issued_instr       [1:0];
    logic                                   w_alu_req_ready          [1:0];
    logic                                   w_alu_req_valid          [1:0];
    logic  [$clog2(NUM_HW_THRDS)-1:0]       w_alu_res_thrd_id        [1:0];
    logic                                   w_alu_res_valid          [1:0];
    logic                                   w_alu_res_ready          [1:0];
    logic  [XLEN-1:0]                       w_alu_result             [1:0];
    logic  [VIR_ADDR_W-1:0]                 w_alu_br_target          [1:0];
    logic                                   w_alu_br_taken           [1:0];
    alu_fifo_entry_t                        w_alu_fifo_head_data;
    alu_fifo_entry_t                        w_alu_fifo_enq_data;
    logic                                   w_alu_fifo_lane_1_valid;
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_alu_fifo_lane_1_thrd_id;

    issue_instr_t                           w_fpu_issued_instr;
    logic                                   w_fpu_req_ready;
    logic                                   w_fpu_req_valid;
    logic  [$clog2(NUM_HW_THRDS)-1:0]       w_fpu_res_thrd_id;
    logic                                   w_fpu_res_valid;
    logic                                   w_fpu_res_ready;
    logic  [XLEN-1:0]                       w_fpu_result;

    logic                                   w_csr_we;
    logic  [XLEN-1:0]                       w_csr_rs1_data_vec         [NUM_HW_THRDS-1:0];
    logic  [XLEN-1:0]                       w_csr_rd_wdata;
    logic  [XLEN-1:0]                       s0_p3_csr_operand;
    logic  [$clog2(CSR_COUNT)-1:0]          w_csr_rs1_addr_vec         [NUM_HW_THRDS-1:0];
    logic  [NUM_HW_THRDS-1:0]               w_irq_pending_vec;
    logic  [$clog2(CSR_COUNT)-1:0]          w_csr_rd_addr;
    logic  [$clog2(NUM_HW_THRDS)-1:0]       w_csr_wthrd_id;
    logic                                   w_csr_trap_we;
    logic                                   w_csr_mret_we;
    logic                                   w_csr_sret_we;
    logic [XLEN-1:0]                        w_csr_trap_mepc;
    logic [XLEN-1:0]                        w_csr_trap_mcause;
    logic [XLEN-1:0]                        w_csr_trap_tval;
    logic                                   w_csr_trap_to_s;
    logic [PRIV_MODE_W-1:0]                 w_csr_priv_mode_vec         [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_csr_medeleg_vec           [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_csr_mideleg_vec           [NUM_HW_THRDS-1:0];
    always_comb begin
        r_lsu_resp_valid      = 1'b0;
        r_lsu_pf_valid        = 1'b0;
        r_lsu_request_pending = 1'b0;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            r_lsu_resp_valid      |= r_lsu_resp_valid_vec[i];
            r_lsu_pf_valid        |= r_lsu_pf_valid_vec[i];
            r_lsu_request_pending |= r_lsu_request_pending_vec[i];
        end
    end

    decoder decoder_0 (
        .i_instr                            (w_decoder_instr),
        .o_decoded                          (w_decoder_decoded_instr)
    );
    decoder decoder_1 (
        .i_instr                            (w_decoder_instr_1),
        .o_decoded                          (w_decoder_decoded_instr_1)
    );
    /*
    regfile regfile_0 (
        .i_clk                              (i_clk),
        .i_we                               (w_regfile_we),
        .i_rs1_addr                         (w_regfile_rs1_addr),
        .i_rs2_addr                         (w_regfile_rs2_addr),
        .i_rs3_addr                         (w_regfile_rs3_addr),
        .i_rthrd_id                         (w_regfile_rthrd_id),
        .i_rd_addr                          (w_regfile_rd_addr),
        .i_wthrd_id                         (w_regfile_wthrd_id),
        .i_rd_wdata                         (w_regfile_rd_wdata),
        .o_rs1_data                         (w_regfile_rs1_data),
        .o_rs2_data                         (w_regfile_rs2_data),
        .o_rs3_data                         (w_regfile_rs3_data)
    );
    */
    threaded_regfile threaded_regfile_0 (
        .i_clk                              (i_clk),
        .i_we                               (w_regfile_we_vec),
        .i_rs1_addr                         (w_regfile_rs1_addr_vec),
        .i_rs2_addr                         (w_regfile_rs2_addr_vec),
        .i_rs3_addr                         (w_regfile_rs3_addr_vec),
        .i_rd_addr                          (w_regfile_rd_addr_vec),
        .i_rd_wdata                         (w_regfile_rd_wdata_vec),
        .o_rs1_data                         (w_regfile_rs1_data_vec),
        .o_rs2_data                         (w_regfile_rs2_data_vec),
        .o_rs3_data                         (w_regfile_rs3_data_vec)
    );
    for (genvar i = 0; i < NUM_HW_THRDS; i++) begin: gen_issue_fifo
        circular_buffer #(
            .DEPTH                          (ISSUE_Q_DEPTH),
            .WIDTH                          ($bits(issue_instr_t))
        ) issue_fifo (
            .i_clk                          (i_clk),
            .i_rst_n                        (i_rst_n),
            .o_head_data                    (w_ififo_head_data_vec[i]),
            .o_deq_ready                    (w_ififo_deq_ready_vec[i]),
            .i_deq_valid                    (w_ififo_deq_valid_vec[i]),
            .i_enq_tail_data                (w_ififo_enq_data_vec[i]),
            .i_enq_valid                    (w_ififo_enq_valid_vec[i]),
            .o_enq_ready                    (w_ififo_enq_ready_vec[i]),
            .o_full                         (),
            .o_empty                        (),
            .o_level                        (w_ififo_level[i]),
            .i_clr_n                        (w_ififo_clr_n[i])
        );
    end
    for (genvar i = 0; i < FU_COUNT; i++) begin: gen_fu_fifo
        if (i == FU_ALU) begin: gen_alu_fifo
            circular_buffer #(
                .DEPTH                      (FU_Q_DEPTH),
                .WIDTH                      ($bits(alu_fifo_entry_t))
            ) fu_fifo (
                .i_clk                      (i_clk),
                .i_rst_n                    (i_rst_n),
                .o_head_data                (w_alu_fifo_head_data),
                .o_deq_ready                (w_fu_fifo_deq_ready[i]),
                .i_deq_valid                (w_fu_fifo_deq_valid[i]),
                .i_enq_tail_data            (w_alu_fifo_enq_data),
                .i_enq_valid                (w_fu_fifo_enq_valid[i]),
                .o_enq_ready                (w_fu_fifo_enq_ready[i]),
                .o_full                     (),
                .o_empty                    (),
                .o_level                    (w_fu_fifo_level[i]),
                .i_clr_n                    (1'b1)
            );
            assign w_fu_fifo_head_data[i] = w_alu_fifo_head_data.instr[0];
        end else if (i == FU_BRU) begin: gen_unused_bru_fifo
            assign w_fu_fifo_head_data[i] = '0;
            assign w_fu_fifo_deq_ready[i] = 1'b0;
            assign w_fu_fifo_enq_ready[i] = 1'b0;
            assign w_fu_fifo_level[i]     = '0;
        end else begin: gen_single_fifo
            circular_buffer #(
                .DEPTH                      (FU_Q_DEPTH),
                .WIDTH                      ($bits(issue_instr_t))
            ) fu_fifo (
                .i_clk                      (i_clk),
                .i_rst_n                    (i_rst_n),
                .o_head_data                (w_fu_fifo_head_data[i]),
                .o_deq_ready                (w_fu_fifo_deq_ready[i]),
                .i_deq_valid                (w_fu_fifo_deq_valid[i]),
                .i_enq_tail_data            (w_fu_fifo_enq_data[i]),
                .i_enq_valid                (w_fu_fifo_enq_valid[i]),
                .o_enq_ready                (w_fu_fifo_enq_ready[i]),
                .o_full                     (),
                .o_empty                    (),
                .o_level                    (w_fu_fifo_level[i]),
                .i_clr_n                    (1'b1)
            );
        end
    end
    alu alu_0 (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .i_issued_instr                     (w_alu_issued_instr),
        .o_req_ready                        (w_alu_req_ready),
        .i_req_valid                        (w_alu_req_valid),
        .o_res_thrd_id                      (w_alu_res_thrd_id),
        .o_br_target                        (w_alu_br_target),
        .o_br_taken                         (w_alu_br_taken),
        .o_res_valid                        (w_alu_res_valid),
        .i_res_ready                        (w_alu_res_ready),
        .o_result                           (w_alu_result)
    );
    fpu fpu_0 (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .i_issued_instr                     (w_fpu_issued_instr),
        .o_req_ready                        (w_fpu_req_ready),
        .i_req_valid                        (w_fpu_req_valid),
        .o_res_thrd_id                      (w_fpu_res_thrd_id),
        .o_res_valid                        (w_fpu_res_valid),
        .i_res_ready                        (w_fpu_res_ready),
        .o_result                           (w_fpu_result)
    );
    csr csr_0 (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .i_thread_id_vec                    (i_thrd_id_vec),
        .i_we                               (w_csr_we),
        .i_irq_timer_vec                    (i_irq_timer_vec),
        .o_irq_pending_vec                  (w_irq_pending_vec),
        .i_rs1_addr_vec                     (w_csr_rs1_addr_vec),
        .i_rd_addr                          (w_csr_rd_addr),
        .i_wthrd_id                         (w_csr_wthrd_id),
        .i_rd_wdata                         (w_csr_rd_wdata),
        .i_trap_we                          (w_csr_trap_we),
        .i_trap_mepc                        (w_csr_trap_mepc),
        .i_trap_mcause                      (w_csr_trap_mcause),
        .i_trap_tval                        (w_csr_trap_tval),
        .i_trap_to_s                        (w_csr_trap_to_s),
        .i_mret_we                          (w_csr_mret_we),
        .i_sret_we                          (w_csr_sret_we),
        .o_rs1_data_vec                     (w_csr_rs1_data_vec),
        .o_priv_mode_vec                    (w_csr_priv_mode_vec),
        .o_medeleg_vec                      (w_csr_medeleg_vec),
        .o_mideleg_vec                      (w_csr_mideleg_vec)
    );
    
    logic [REG_COUNT-1:0]                   r_scb                   [NUM_HW_THRDS-1:0];
    logic [CSR_COUNT-1:0]                   r_csr_scb               [NUM_HW_THRDS-1:0];
    /* ---**/



    /* 0. Frontend(fetch,decode)---  */
    /* s0--- */
    // public s1_*
    logic [VIR_ADDR_W-1:0]                  s1_p0_npc                [NUM_HW_THRDS-1:0];
    logic [VIR_ADDR_W-1:0]                  s1_p0_fetch_pc           [NUM_HW_THRDS-1:0];
    logic [NUM_HW_THRDS-1:0]                s1_p0_sleep;
    logic                                   s1_p0_npc_valid          [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_fetch_pending      [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_instr_valid        [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        s1_p0_instr              [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_instr_line_valid   [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_instr_is_pf        [NUM_HW_THRDS-1:0];
    logic [isa_pkg::TRAP_CAUSE_W-1:0]       s1_p0_instr_pf_cause     [NUM_HW_THRDS-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        s1_p0_fetch_last_thrd_id;
    logic                                   r_p0_drop_resp           [NUM_HW_THRDS-1:0];

    // private s0_*
    logic [$clog2(NUM_HW_THRDS)-1:0]        s0_p0_fetch_thrd_id;
    logic                                   s0_p0_fetch_found;
    generic_page_msg_t                      s0_p0_page_msg_instr;
    page_fault_msg_t                        s0_p0_pf_msg_instr;

    // s0 combinational logic
    assign o_req_instr_addr        = {s1_p0_npc[s0_p0_fetch_thrd_id][VIR_ADDR_W-1:3], 3'b000};
    assign o_req_instr_thrd_id     = s0_p0_fetch_thrd_id;
    assign o_req_instr_priv        = w_csr_priv_mode_vec[s0_p0_fetch_thrd_id];
    assign o_req_instr_valid       = s0_p0_fetch_found;
    assign o_resp_instr_ready      = r_p0_drop_resp[i_resp_instr_thrd_id] ||
                                     !s1_p0_instr_valid[i_resp_instr_thrd_id];
    assign o_page_msg_instr_ready  = 1'b1;
    assign s0_p0_page_msg_instr    = i_page_msg_instr;
    assign s0_p0_pf_msg_instr      = i_page_msg_instr;

    always_comb begin
        s0_p0_fetch_thrd_id = '0;
        s0_p0_fetch_found   = 1'b0;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic int fi = (int'(s1_p0_fetch_last_thrd_id) + 1 + i) % NUM_HW_THRDS;
            if (!s0_p0_fetch_found && s1_p0_npc_valid[fi] && !s1_p0_fetch_pending[fi] &&
                !s1_p0_instr_valid[fi] && !s1_p0_sleep[fi]) begin
                s0_p0_fetch_thrd_id = fi[$clog2(NUM_HW_THRDS)-1:0];
                s0_p0_fetch_found   = 1'b1;
            end
        end
    end

    // s0->s1 registering
    always_ff @(posedge i_clk) begin: s0_pr_s1
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                s1_p0_npc[i]            <= RESET_VEC;
                s1_p0_fetch_pc[i]       <= RESET_VEC;
                s1_p0_npc_valid[i]      <= 1'b1;
                s1_p0_fetch_pending[i]  <= 1'b0;
                s1_p0_sleep[i]          <= (i != 0);    /* arch. parking... */
                s1_p0_instr_valid[i]    <= 1'b0;
                s1_p0_instr_line_valid[i] <= 1'b0;
                s1_p0_instr_is_pf[i]    <= 1'b0;
                s1_p0_instr_pf_cause[i] <= '0;
                r_p0_drop_resp[i]       <= 1'b0;
            end
            s1_p0_fetch_last_thrd_id <= '0;
        end else begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (i_wake_intr_vec[i]) begin
                    s1_p0_sleep[i] <= 1'b0;
                end else if (w_ififo_deq_valid && w_ififo_deq_ready &&
                    w_ififo_head_data.instr.is_wfi &&
                    w_ififo_head_data.thrd_id == i[$clog2(NUM_HW_THRDS)-1:0]) begin
                    s1_p0_sleep[i] <= 1'b1;
                end
            end

            if (i_req_instr_ready && o_req_instr_valid) begin
                s1_p0_npc_valid[s0_p0_fetch_thrd_id] <= 1'b0;
                s1_p0_fetch_pc[s0_p0_fetch_thrd_id]  <= s1_p0_npc[s0_p0_fetch_thrd_id];
                s1_p0_fetch_pending[s0_p0_fetch_thrd_id] <= 1'b1;
                s1_p0_fetch_last_thrd_id             <= s0_p0_fetch_thrd_id;
            end
            if (i_resp_instr_valid && o_resp_instr_ready) begin
                s1_p0_fetch_pending[i_resp_instr_thrd_id] <= 1'b0;
                if (r_p0_drop_resp[i_resp_instr_thrd_id]) begin
                    r_p0_drop_resp[i_resp_instr_thrd_id] <= 1'b0;
                end else begin
                    s1_p0_instr[i_resp_instr_thrd_id]         <= i_resp_instr;
                    s1_p0_instr_valid[i_resp_instr_thrd_id]   <= 1'b1;
                    s1_p0_instr_line_valid[i_resp_instr_thrd_id] <= 1'b1;
                end
            end else if (i_page_msg_instr_valid && o_page_msg_instr_ready) begin
                if (s0_p0_page_msg_instr.msg_type == PAGE_MSG_FAULT) begin
                    s1_p0_fetch_pending[s0_p0_pf_msg_instr.thrd_id] <= 1'b0;
                    if (r_p0_drop_resp[s0_p0_pf_msg_instr.thrd_id]) begin
                        r_p0_drop_resp[s0_p0_pf_msg_instr.thrd_id] <= 1'b0;
                    end else begin
                        s1_p0_instr[s0_p0_pf_msg_instr.thrd_id]          <= '0;
                        s1_p0_instr_valid[s0_p0_pf_msg_instr.thrd_id]    <= 1'b1;
                        s1_p0_instr_line_valid[s0_p0_pf_msg_instr.thrd_id] <= 1'b0;
                        s1_p0_instr_is_pf[s0_p0_pf_msg_instr.thrd_id]    <= 1'b1;
                        s1_p0_instr_pf_cause[s0_p0_pf_msg_instr.thrd_id] <= isa_pkg::TRAP_CAUSE_INST_PAGE_FAULT;
                    end
                end
            end
            if (s1_p0_issue_found) begin
                s1_p0_instr_valid[s1_p0_issue_thrd_id] <= 1'b0;
                s1_p0_instr_is_pf[s1_p0_issue_thrd_id] <= 1'b0;
                if (s1_p0_predict_valid) begin
                    if (s1_p0_instr_line_valid[s1_p0_issue_thrd_id] &&
                        !s1_p0_fetch_pc[s1_p0_issue_thrd_id][2]) begin
                        s1_p0_fetch_pc[s1_p0_issue_thrd_id] <=
                            s1_p0_fetch_pc[s1_p0_issue_thrd_id] + VIR_ADDR_W'(INST_W / 8);
                        s1_p0_npc_valid[s1_p0_issue_thrd_id]   <= 1'b0;
                        s1_p0_instr_valid[s1_p0_issue_thrd_id] <= 1'b1;
                    end else begin
                        s1_p0_npc[s1_p0_issue_thrd_id] <=
                            s1_p0_fetch_pc[s1_p0_issue_thrd_id] + VIR_ADDR_W'(INST_W / 8);
                        s1_p0_npc_valid[s1_p0_issue_thrd_id] <= 1'b1;
                        s1_p0_instr_line_valid[s1_p0_issue_thrd_id] <= 1'b0;
                    end
                end
            end
            if (s1_p0_issue_found_1) begin
                s1_p0_instr_valid[s1_p0_issue_thrd_id_1] <= 1'b0;
                s1_p0_instr_is_pf[s1_p0_issue_thrd_id_1] <= 1'b0;
                if (s1_p0_predict_valid_1) begin
                    if (s1_p0_instr_line_valid[s1_p0_issue_thrd_id_1] &&
                        !s1_p0_fetch_pc[s1_p0_issue_thrd_id_1][2]) begin
                        s1_p0_fetch_pc[s1_p0_issue_thrd_id_1] <=
                            s1_p0_fetch_pc[s1_p0_issue_thrd_id_1] + VIR_ADDR_W'(INST_W / 8);
                        s1_p0_npc_valid[s1_p0_issue_thrd_id_1]   <= 1'b0;
                        s1_p0_instr_valid[s1_p0_issue_thrd_id_1] <= 1'b1;
                    end else begin
                        s1_p0_npc[s1_p0_issue_thrd_id_1] <=
                            s1_p0_fetch_pc[s1_p0_issue_thrd_id_1] + VIR_ADDR_W'(INST_W / 8);
                        s1_p0_npc_valid[s1_p0_issue_thrd_id_1] <= 1'b1;
                        s1_p0_instr_line_valid[s1_p0_issue_thrd_id_1] <= 1'b0;
                    end
                end
            end
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (s1_p0_backend_fb_valid[i]) begin
                    if (s1_p0_instr_line_valid[i] &&
                        !s1_p0_fetch_pc[i][2] &&
                        s1_p0_backend_fb_npc[i] ==
                            (s1_p0_fetch_pc[i] + VIR_ADDR_W'(INST_W / 8))) begin
                        s1_p0_fetch_pc[i]    <= s1_p0_backend_fb_npc[i];
                        s1_p0_npc_valid[i]   <= 1'b0;
                        s1_p0_instr_valid[i] <= 1'b1;
                    end else begin
                        s1_p0_npc[i]              <= s1_p0_backend_fb_npc[i];
                        s1_p0_npc_valid[i]        <= 1'b1;
                        s1_p0_instr_valid[i]      <= 1'b0;
                        s1_p0_instr_line_valid[i] <= 1'b0;
                    end
                end
                if (s1_p0_backend_fb_redirect[i]) begin
                    if (s1_p0_fetch_pending[i])
                        r_p0_drop_resp[i] <= 1'b1;
                end
            end
        end
    end: s0_pr_s1
    /* ---s0 */

    /* s1--- */
    // public s2_*
    decoded_instr_t                         s2_p0_fe_decoded_instr       [NUM_HW_THRDS-1:0];
    logic                                   s2_p0_fe_decoded_instr_valid [NUM_HW_THRDS-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        s2_p0_issue_last_thrd_id;

    // private s1_*
    logic [$clog2(NUM_HW_THRDS)-1:0]        s1_p0_issue_thrd_id;
    logic                                   s1_p0_issue_found;
    logic [$clog2(NUM_HW_THRDS)-1:0]        s1_p0_issue_thrd_id_1;
    logic                                   s1_p0_issue_found_1;
    logic                                   s1_p0_backend_consume        [NUM_HW_THRDS-1:0];
    logic [VIR_ADDR_W-1:0]                  s1_p0_backend_fb_npc       [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_backend_fb_valid     [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_backend_fb_redirect  [NUM_HW_THRDS-1:0];
    logic                                   s1_p0_predict_valid;
    logic                                   s1_p0_predict_valid_1;
    generic_page_msg_t                      s1_p0_page_msg_data;
    page_fault_msg_t                        s1_p0_pf_msg_data;

    // s1 combinational logic
    assign w_decoder_instr        = s1_p0_fetch_pc[s1_p0_issue_thrd_id][2] ?
                                    s1_p0_instr[s1_p0_issue_thrd_id][2*INST_W-1:INST_W] :
                                    s1_p0_instr[s1_p0_issue_thrd_id][INST_W-1:0];
    assign w_decoder_instr_1      = s1_p0_fetch_pc[s1_p0_issue_thrd_id_1][2] ?
                                    s1_p0_instr[s1_p0_issue_thrd_id_1][2*INST_W-1:INST_W] :
                                    s1_p0_instr[s1_p0_issue_thrd_id_1][INST_W-1:0];
    assign o_page_msg_data_ready  = !r_lsu_pf_valid_vec[s1_p0_pf_msg_data.thrd_id[$clog2(NUM_HW_THRDS)-1:0]];
    assign s1_p0_page_msg_data    = i_page_msg_data;
    assign s1_p0_pf_msg_data      = i_page_msg_data;
    assign s1_p0_predict_valid    = s1_p0_issue_found &&
                                    !w_decoder_decoded_instr.is_branch &&
                                    !w_decoder_decoded_instr.is_jump &&
                                    !w_decoder_decoded_instr.is_ecall &&
                                    !w_decoder_decoded_instr.is_sret &&
                                    !w_decoder_decoded_instr.is_mret &&
                                    !w_decoder_decoded_instr.is_wfi &&
                                    w_decoder_decoded_instr.fu != FU_CSR &&
                                    !s1_p0_instr_is_pf[s1_p0_issue_thrd_id];
    assign s1_p0_predict_valid_1  = s1_p0_issue_found_1 &&
                                    !w_decoder_decoded_instr_1.is_branch &&
                                    !w_decoder_decoded_instr_1.is_jump &&
                                    !w_decoder_decoded_instr_1.is_ecall &&
                                    !w_decoder_decoded_instr_1.is_sret &&
                                    !w_decoder_decoded_instr_1.is_mret &&
                                    !w_decoder_decoded_instr_1.is_wfi &&
                                    w_decoder_decoded_instr_1.fu != FU_CSR &&
                                    !s1_p0_instr_is_pf[s1_p0_issue_thrd_id_1];

    always_comb begin
        s1_p0_issue_thrd_id = '0;
        s1_p0_issue_found   = 1'b0;
        s1_p0_issue_thrd_id_1 = '0;
        s1_p0_issue_found_1   = 1'b0;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic int ii = (int'(s2_p0_issue_last_thrd_id) + 1 + i) % NUM_HW_THRDS;
            if (!s1_p0_issue_found && s1_p0_instr_valid[ii] && !s2_p0_fe_decoded_instr_valid[ii] && !s1_p0_sleep[ii]) begin
                s1_p0_issue_thrd_id = ii[$clog2(NUM_HW_THRDS)-1:0];
                s1_p0_issue_found   = 1'b1;
            end
        end
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic int ii = (int'(s1_p0_issue_thrd_id) + 1 + i) % NUM_HW_THRDS;
            if (!s1_p0_issue_found_1 && s1_p0_issue_found &&
                ii != int'(s1_p0_issue_thrd_id) && s1_p0_instr_valid[ii] &&
                !s2_p0_fe_decoded_instr_valid[ii] && !s1_p0_sleep[ii]) begin
                s1_p0_issue_thrd_id_1 = ii[$clog2(NUM_HW_THRDS)-1:0];
                s1_p0_issue_found_1   = 1'b1;
            end
        end
    end

    // s1->s2 registering
    always_ff @(posedge i_clk) begin: s1_pr_s2
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                s2_p0_fe_decoded_instr_valid[i] <= 1'b0;
            end
            s2_p0_issue_last_thrd_id <= '0;
        end else begin
            if (s1_p0_issue_found) begin
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id]               <= w_decoder_decoded_instr;
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id].pc            <= s1_p0_fetch_pc[s1_p0_issue_thrd_id];
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id].is_page_fault <= s1_p0_instr_is_pf[s1_p0_issue_thrd_id];
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id].trap_cause    <= s1_p0_instr_pf_cause[s1_p0_issue_thrd_id];
                s2_p0_fe_decoded_instr_valid[s1_p0_issue_thrd_id]         <= 1'b1;
                s2_p0_issue_last_thrd_id                                  <= s1_p0_issue_thrd_id;
            end
            if (s1_p0_issue_found_1) begin
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id_1]               <= w_decoder_decoded_instr_1;
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id_1].pc            <= s1_p0_fetch_pc[s1_p0_issue_thrd_id_1];
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id_1].is_page_fault <= s1_p0_instr_is_pf[s1_p0_issue_thrd_id_1];
                s2_p0_fe_decoded_instr[s1_p0_issue_thrd_id_1].trap_cause    <= s1_p0_instr_pf_cause[s1_p0_issue_thrd_id_1];
                s2_p0_fe_decoded_instr_valid[s1_p0_issue_thrd_id_1]         <= 1'b1;
                s2_p0_issue_last_thrd_id                                    <= s1_p0_issue_thrd_id_1;
            end
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (s1_p0_backend_fb_redirect[i] ||
                    (s1_p0_backend_consume[i] && s2_p0_fe_decoded_instr_valid[i])) begin
                    s2_p0_fe_decoded_instr_valid[i] <= 1'b0;
                end
            end
        end
    end: s1_pr_s2
    /* ---s1 */

    /* s2--- */
    // public s3_*
    decoded_instr_t                         s3_p0_fe_decoded_instr       [NUM_HW_THRDS-1:0];
    logic                                   s3_p0_fe_decoded_instr_valid [NUM_HW_THRDS-1:0];
    logic [NUM_HW_THRDS-1:0]                s3_p0_fe_sleep;
    generic_page_msg_t                      s3_p0_fe_page_msg_data;

    // private s2_*
    // ...

    // s2 combinational logic
    assign s3_p0_fe_decoded_instr       = s2_p0_fe_decoded_instr;
    assign s3_p0_fe_decoded_instr_valid = s2_p0_fe_decoded_instr_valid;
    assign s3_p0_fe_sleep               = s1_p0_sleep;
    assign s3_p0_fe_page_msg_data       = s1_p0_page_msg_data;

    for (genvar i = 0; i < NUM_HW_THRDS; i++) begin: gen_ififo_clear
        assign w_ififo_clr_n[i] = !s1_p0_backend_fb_redirect[i];
    end

    // ...
    /* ---s2 */
    // ...
    /*  ---Frontend */




    /* 1. Issue---  */
    logic                                     s0_p1_rs1_ok            [NUM_HW_THRDS-1:0];
    logic                                     s0_p1_rs2_ok            [NUM_HW_THRDS-1:0];
    logic                                     s0_p1_rs3_ok            [NUM_HW_THRDS-1:0];
    logic                                     s0_p1_candidate         [NUM_HW_THRDS-1:0];
    logic                                     s1_p1_candidate         [NUM_HW_THRDS-1:0];
    logic                                     s1_p1_from_queue        [NUM_HW_THRDS-1:0];
    decoded_instr_t                           s1_p1_decoded_instr     [NUM_HW_THRDS-1:0];
    logic                                     s1_p1_trap_to_s         [NUM_HW_THRDS-1:0];
    logic [NUM_HW_THRDS-1:0]                  w_s0_p1_take_irq;

    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic decoded_instr_t instr = w_ififo_head_data_vec[i].instr;
            automatic logic [$clog2(CSR_COUNT)-1:0] csr_rd_idx = instr.is_sret  ? core_pkg::CSR_SEPC :
                                                                    instr.is_mret  ? core_pkg::CSR_MEPC :
                                                                    instr.is_ecall ? core_pkg::CSR_MTVEC :
                                                                    csr_addr_decode(instr.imm[isa_pkg::CSR_ADDR_W-1:0]);
            automatic logic reads_csr = instr.is_sret || instr.is_mret || instr.is_ecall || (instr.fu == FU_CSR);
            automatic logic csr_ok    = !reads_csr || !r_csr_scb[i][csr_rd_idx];
            w_s0_p1_take_irq[i] = w_irq_pending_vec[i] && !w_ififo_deq_ready_vec[i] &&
                                  !r_rob_valid[i] && !s3_p0_fe_sleep[i];
            s0_p1_rs1_ok[i]     = !r_scb[i][instr.rs1];
            s0_p1_rs2_ok[i]     = !r_scb[i][instr.rs2];
            s0_p1_rs3_ok[i]     = !r_scb[i][instr.rs3];
            if (w_s0_p1_take_irq[i]) begin
                s0_p1_candidate[i] = 1'b1;
            end else begin
                case (instr.rawhz_t)
                    RAWHZ_NONE:        s0_p1_candidate[i] = w_ififo_deq_ready_vec[i] && !r_rob_valid[i] && csr_ok && !s3_p0_fe_sleep[i];
                    RAWHZ_RS1:         s0_p1_candidate[i] = w_ififo_deq_ready_vec[i] && !r_rob_valid[i] && s0_p1_rs1_ok[i] && csr_ok && !s3_p0_fe_sleep[i];
                    RAWHZ_RS1_RS2:     s0_p1_candidate[i] = w_ififo_deq_ready_vec[i] && !r_rob_valid[i] && s0_p1_rs1_ok[i] && s0_p1_rs2_ok[i] && csr_ok && !s3_p0_fe_sleep[i];
                    RAWHZ_RS1_RS2_RS3: s0_p1_candidate[i] = w_ififo_deq_ready_vec[i] && !r_rob_valid[i] && s0_p1_rs1_ok[i] && s0_p1_rs2_ok[i] && s0_p1_rs3_ok[i] && csr_ok && !s3_p0_fe_sleep[i];
                    default:           s0_p1_candidate[i] = 1'b0;
                endcase
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                s1_p1_candidate[i]     <= 1'b0;
                s1_p1_from_queue[i]    <= 1'b0;
                s1_p1_decoded_instr[i] <= '0;
            end
        end else begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                s1_p1_candidate[i]  <= s0_p1_candidate[i];
                s1_p1_from_queue[i] <= w_ififo_deq_ready_vec[i];
                if (w_s0_p1_take_irq[i]) begin
                    s1_p1_decoded_instr[i]               <= '0;
                    s1_p1_decoded_instr[i].is_page_fault <= 1'b1;
                    s1_p1_decoded_instr[i].trap_cause    <= IRQ_CAUSE_MACHINE_TIMER;
                    s1_p1_decoded_instr[i].pc            <= s1_p0_npc_valid[i] ?
                                                            s1_p0_npc[i] :
                                                            s1_p0_fetch_pc[i];
                end else begin
                    s1_p1_decoded_instr[i] <= w_ififo_head_data_vec[i].instr;
                end
            end
        end
    end

    for (genvar i = 0; i < NUM_HW_THRDS; i++) begin: gen_issue_read_addr
        assign w_regfile_rs1_addr_vec[i] = w_ififo_head_data_vec[i].instr.rs1;
        assign w_regfile_rs2_addr_vec[i] = w_ififo_head_data_vec[i].instr.rs2;
        assign w_regfile_rs3_addr_vec[i] = w_ififo_head_data_vec[i].instr.rs3;
    end

    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic decoded_instr_t instr = s1_p1_decoded_instr[i];
            automatic logic trap_is_irq = instr.is_page_fault && instr.trap_cause[TRAP_CAUSE_W-1];
            automatic logic [TRAP_CAUSE_CODE_W-1:0] trap_code;
            if (instr.is_ecall) begin
                case (w_csr_priv_mode_vec[i])
                    PRIV_MODE_U: trap_code = TRAP_CAUSE_CODE_W'(TRAP_CAUSE_ECALL_U);
                    PRIV_MODE_S: trap_code = TRAP_CAUSE_CODE_W'(TRAP_CAUSE_ECALL_S);
                    default:     trap_code = TRAP_CAUSE_CODE_W'(TRAP_CAUSE_ECALL_M);
                endcase
            end else if (instr.fu == FU_LSU) begin
                trap_code = instr.ls_wen ? TRAP_CAUSE_CODE_W'(TRAP_CAUSE_STORE_PAGE_FAULT) :
                                           TRAP_CAUSE_CODE_W'(TRAP_CAUSE_LOAD_PAGE_FAULT);
            end else begin
                trap_code = instr.trap_cause[TRAP_CAUSE_CODE_W-1:0];
            end
            s1_p1_trap_to_s[i] = trap_is_irq ? ((w_csr_priv_mode_vec[i] != PRIV_MODE_M) && w_csr_mideleg_vec[i][trap_code]) :
                                               ((w_csr_priv_mode_vec[i] == PRIV_MODE_U) && w_csr_medeleg_vec[i][trap_code]);
            w_csr_rs1_addr_vec[i] = (instr.is_ecall || instr.is_page_fault || instr.fu == FU_LSU) ?
                                    (s1_p1_trap_to_s[i] ? core_pkg::CSR_STVEC : core_pkg::CSR_MTVEC) :
                                    instr.is_sret ? core_pkg::CSR_SEPC :
                                    instr.is_mret ? core_pkg::CSR_MEPC :
                                    csr_addr_decode(instr.imm[isa_pkg::CSR_ADDR_W-1:0]);
        end
    end

    assign w_csr_rd_addr = csr_addr_decode(w_ififo_head_data.instr.imm[isa_pkg::CSR_ADDR_W-1:0]);

    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            w_ififo_enq_data_vec[i]         = '0;
            w_ififo_enq_data_vec[i].instr   = s3_p0_fe_decoded_instr[i];
            w_ififo_enq_data_vec[i].thrd_id = i[$clog2(NUM_HW_THRDS)-1:0];
            w_ififo_enq_valid_vec[i]        = s3_p0_fe_decoded_instr_valid[i];
            s1_p0_backend_consume[i]        = w_ififo_enq_valid_vec[i] && w_ififo_enq_ready_vec[i];
        end
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            for (int i = 0; i < FU_COUNT; i++)
                r_fu_last_thrd_id[i] <= '0;
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                r_rob_instr[i]             <= '0;
                r_rob_valid[i]             <= 1'b0;
                r_rob_dispatched[i]        <= 1'b0;
                r_rob_immediate_done[i]    <= 1'b0;
            end
        end else begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (w_commit_valid_vec[i]) begin
                    r_rob_valid[i]          <= 1'b0;
                    r_rob_dispatched[i]     <= 1'b0;
                    r_rob_immediate_done[i] <= 1'b0;
                end
            end
            for (int i = 0; i < FU_COUNT; i++) begin
                if (w_fu_fifo_enq_fire[i]) begin
                    automatic logic [$clog2(NUM_HW_THRDS)-1:0] thrd = w_fu_winner_thrd_id[i];
                    r_fu_last_thrd_id[i]  <= thrd;
                    r_rob_instr[thrd]     <= w_fu_fifo_enq_data[i];
                    r_rob_valid[thrd]     <= 1'b1;
                    r_rob_dispatched[thrd] <= 1'b1;
                    if (i == FU_ALU && w_alu_fifo_lane_1_valid) begin
                        r_fu_last_thrd_id[i] <= w_alu_fifo_lane_1_thrd_id;
                        r_rob_instr[w_alu_fifo_lane_1_thrd_id] <= w_alu_fifo_enq_data.instr[1];
                        r_rob_valid[w_alu_fifo_lane_1_thrd_id] <= 1'b1;
                        r_rob_dispatched[w_alu_fifo_lane_1_thrd_id] <= 1'b1;
                    end
                end
                if (w_fu_fifo_deq_valid[i] && w_fu_fifo_deq_ready[i] &&
                    (w_fu_fifo_head_data[i].instr.is_page_fault ||
                     (w_fu_fifo_head_data[i].instr.fu != FU_ALU &&
                      w_fu_fifo_head_data[i].instr.fu != FU_BRU &&
                      w_fu_fifo_head_data[i].instr.fu != FU_FPU &&
                      w_fu_fifo_head_data[i].instr.fu != FU_LSU))) begin
                    r_rob_immediate_done[w_fu_fifo_head_data[i].thrd_id] <= 1'b1;
                end
            end
        end
    end
    /*  ---Issue */




    /* 2. Dispatch---  */
    /* s0--- */
    // public s1_*
    // ...

    // private s0_*
    issue_instr_t                           s0_p2_alu_issued_instr    [1:0];
    issue_instr_t                           s0_p2_fpu_issued_instr;
    logic                                   s0_p2_alu_req_valid       [1:0];
    logic                                   s0_p2_fpu_req_valid;
    logic [VIR_ADDR_W-1:0]                  s0_p2_req_data_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0]        s0_p2_req_data_thrd_id;
    logic [PRIV_MODE_W-1:0]                 s0_p2_req_data_priv;
    logic                                   s0_p2_req_data_rw;
    logic [XLEN/8-1:0]                      s0_p2_req_data_wstrb;
    logic [XLEN-1:0]                        s0_p2_req_data_wdata;
    logic                                   s0_p2_req_data_lq;
    logic                                   s0_p2_req_data_sc;
    logic                                   s0_p2_req_data_valid;

    // s0 combinational logic
    always_comb begin
        w_alu_fifo_lane_1_valid   = 1'b0;
        w_alu_fifo_lane_1_thrd_id = '0;
        for (int i = 0; i < FU_COUNT; i++) begin
            w_fu_winner_thrd_id[i] = '0;
            w_fu_winner_valid[i]   = 1'b0;
            w_fu_fifo_enq_data[i]  = '0;
            w_fu_fifo_enq_valid[i] = 1'b0;
            w_fu_fifo_deq_valid[i] = 1'b0;
            for (int j = 0; j < NUM_HW_THRDS; j++) begin
                automatic int ti = (int'(r_fu_last_thrd_id[i]) + 1 + j) % NUM_HW_THRDS;
                if (!w_fu_winner_valid[i] && s1_p1_candidate[ti] && !r_rob_valid[ti] &&
                    ((!s1_p1_from_queue[ti] && w_irq_pending_vec[ti]) ||
                     (s1_p1_from_queue[ti] && w_ififo_deq_ready_vec[ti] &&
                      w_ififo_head_data_vec[ti].instr.pc == s1_p1_decoded_instr[ti].pc)) &&
                    int'(s1_p1_decoded_instr[ti].fu) == i) begin
                    w_fu_winner_thrd_id[i] = ti[$clog2(NUM_HW_THRDS)-1:0];
                    w_fu_winner_valid[i]   = 1'b1;
                    w_fu_fifo_enq_data[i]  = '{
                        instr:     s1_p1_decoded_instr[ti],
                        thrd_id:   ti[$clog2(NUM_HW_THRDS)-1:0],
                        rs1_data:  w_regfile_rs1_data_vec[ti],
                        rs2_data:  w_regfile_rs2_data_vec[ti],
                        rs3_data:  w_regfile_rs3_data_vec[ti],
                        csr_data:  w_csr_rs1_data_vec[ti],
                        trap_to_s: s1_p1_trap_to_s[ti]
                    };
                    w_fu_fifo_enq_valid[i] = 1'b1;
                end
            end
            w_fu_fifo_enq_fire[i] = w_fu_fifo_enq_valid[i] && w_fu_fifo_enq_ready[i];
        end
        if (w_fu_winner_valid[FU_ALU]) begin
            for (int j = 0; j < NUM_HW_THRDS; j++) begin
                automatic int ti = (int'(w_fu_winner_thrd_id[FU_ALU]) + 1 + j) % NUM_HW_THRDS;
                if (!w_alu_fifo_lane_1_valid &&
                    ti != int'(w_fu_winner_thrd_id[FU_ALU]) &&
                    s1_p1_candidate[ti] && !r_rob_valid[ti] &&
                    ((!s1_p1_from_queue[ti] && w_irq_pending_vec[ti]) ||
                     (s1_p1_from_queue[ti] && w_ififo_deq_ready_vec[ti] &&
                      w_ififo_head_data_vec[ti].instr.pc == s1_p1_decoded_instr[ti].pc)) &&
                    s1_p1_decoded_instr[ti].fu == FU_ALU) begin
                    w_alu_fifo_lane_1_valid   = 1'b1;
                    w_alu_fifo_lane_1_thrd_id = ti[$clog2(NUM_HW_THRDS)-1:0];
                end
            end
        end
        w_alu_fifo_enq_data.valid    = {w_alu_fifo_lane_1_valid, w_fu_winner_valid[FU_ALU]};
        w_alu_fifo_enq_data.instr[0] = w_fu_fifo_enq_data[FU_ALU];
        w_alu_fifo_enq_data.instr[1] = '{
            instr:     s1_p1_decoded_instr[w_alu_fifo_lane_1_thrd_id],
            thrd_id:   w_alu_fifo_lane_1_thrd_id,
            rs1_data:  w_regfile_rs1_data_vec[w_alu_fifo_lane_1_thrd_id],
            rs2_data:  w_regfile_rs2_data_vec[w_alu_fifo_lane_1_thrd_id],
            rs3_data:  w_regfile_rs3_data_vec[w_alu_fifo_lane_1_thrd_id],
            csr_data:  w_csr_rs1_data_vec[w_alu_fifo_lane_1_thrd_id],
            trap_to_s: s1_p1_trap_to_s[w_alu_fifo_lane_1_thrd_id]
        };

        w_commit_thrd_id       = '0;
        w_commit_found         = 1'b0;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            w_fast_commit_vec[i] = r_rob_valid[i] && r_rob_dispatched[i] &&
                !r_rob_instr[i].instr.is_page_fault && !r_rob_instr[i].instr.is_ecall &&
                !r_rob_instr[i].instr.is_sret && !r_rob_instr[i].instr.is_mret &&
                !r_rob_instr[i].instr.is_wfi && !r_rob_instr[i].instr.csr_wen &&
                !r_rob_instr[i].instr.is_branch && !r_rob_instr[i].instr.is_jump &&
                ((r_rob_instr[i].instr.fu == FU_ALU &&
                  ((w_alu_res_valid[0] && w_alu_res_thrd_id[0] == i[$clog2(NUM_HW_THRDS)-1:0]) ||
                   (w_alu_res_valid[1] && w_alu_res_thrd_id[1] == i[$clog2(NUM_HW_THRDS)-1:0]))) ||
                 (r_rob_instr[i].instr.fu == FU_FPU &&
                  w_fpu_res_valid && w_fpu_res_thrd_id == i[$clog2(NUM_HW_THRDS)-1:0]) ||
                 (r_rob_instr[i].instr.fu == FU_LSU && r_lsu_resp_valid_vec[i]));
            w_commit_valid_vec[i] = w_fast_commit_vec[i];
        end
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic int ci = (int'(r_commit_last_thrd_id) + 1 + i) % NUM_HW_THRDS;
            automatic logic ci_complete = r_rob_valid[ci] && r_rob_dispatched[ci] &&
                (r_rob_immediate_done[ci] ||
                 (r_rob_instr[ci].instr.fu == FU_ALU &&
                  ((w_alu_res_valid[0] && w_alu_res_thrd_id[0] == ci[$clog2(NUM_HW_THRDS)-1:0]) ||
                   (w_alu_res_valid[1] && w_alu_res_thrd_id[1] == ci[$clog2(NUM_HW_THRDS)-1:0]))) ||
                 (r_rob_instr[ci].instr.fu == FU_FPU && w_fpu_res_valid && w_fpu_res_thrd_id == ci[$clog2(NUM_HW_THRDS)-1:0]) ||
                 (r_rob_instr[ci].instr.fu == FU_LSU &&
                  (r_lsu_resp_valid_vec[ci] || r_lsu_pf_valid_vec[ci])));
            if (!w_commit_found && ci_complete && !w_fast_commit_vec[ci]) begin
                w_commit_thrd_id = ci[$clog2(NUM_HW_THRDS)-1:0];
                w_commit_found   = 1'b1;
            end
        end
        w_ififo_head_data      = r_rob_instr[w_commit_thrd_id];
        w_ififo_deq_ready      = w_commit_found;
        w_ififo_deq_valid      = w_commit_found;
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            if (w_commit_found && w_commit_thrd_id == i[$clog2(NUM_HW_THRDS)-1:0])
                w_commit_valid_vec[i] = 1'b1;
            w_ififo_deq_valid_vec[i] = w_commit_valid_vec[i];
        end

        for (int i = 0; i < 2; i++) begin
            s0_p2_alu_issued_instr[i] = w_alu_fifo_head_data.instr[i];
            s0_p2_alu_req_valid[i]    = w_fu_fifo_deq_ready[FU_ALU] &&
                                        w_alu_fifo_head_data.valid[i] &&
                                        !w_alu_fifo_head_data.instr[i].instr.is_page_fault;
        end
        s0_p2_fpu_issued_instr = w_fu_fifo_head_data[FU_FPU];
        s0_p2_fpu_req_valid    = w_fu_fifo_deq_ready[FU_FPU] &&
                                 !w_fu_fifo_head_data[FU_FPU].instr.is_page_fault;
        s0_p2_req_data_addr    = w_fu_fifo_head_data[FU_LSU].rs1_data + w_fu_fifo_head_data[FU_LSU].instr.imm;
        s0_p2_req_data_thrd_id = w_fu_fifo_head_data[FU_LSU].thrd_id;
        s0_p2_req_data_priv    = w_csr_priv_mode_vec[w_fu_fifo_head_data[FU_LSU].thrd_id];
        s0_p2_req_data_rw      = w_fu_fifo_head_data[FU_LSU].instr.ls_wen;
        s0_p2_req_data_wstrb   = w_fu_fifo_head_data[FU_LSU].instr.ls_lq ?
                                 ((w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_LOAD_I64) ? {(XLEN/8){1'b1}} :
                                  ((XLEN/8)'(4'hf) << (s0_p2_req_data_addr[$clog2(XLEN/8)-1] * 4))) :
                                 !w_fu_fifo_head_data[FU_LSU].instr.ls_wen ? '0 :
                                 (w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_STORE_8  || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_8  || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_8_RL)  ? ((XLEN/8)'(1) << s0_p2_req_data_addr[$clog2(XLEN/8)-1:0]) :
                                 (w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_STORE_32 || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_32 || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_32_RL) ? ((XLEN/8)'(4'hf) << (s0_p2_req_data_addr[$clog2(XLEN/8)-1] * 4)) :
                                 (w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_STORE_64 || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_64 || w_fu_fifo_head_data[FU_LSU].instr.ls_op == LS_CSTORE_64_RL) ? {(XLEN/8){1'b1}} :
                                 ((XLEN/8)'(2'b11) << (s0_p2_req_data_addr[$clog2(XLEN/8)-1:1] * 2));
        s0_p2_req_data_wdata   = ((w_fu_fifo_head_data[FU_LSU].instr.rs2 == '0) ? '0 : w_fu_fifo_head_data[FU_LSU].rs2_data) << (s0_p2_req_data_addr[$clog2(XLEN/8)-1:0] * 8);
        s0_p2_req_data_lq      = w_fu_fifo_head_data[FU_LSU].instr.ls_lq;
        s0_p2_req_data_sc      = w_fu_fifo_head_data[FU_LSU].instr.ls_sc;
        s0_p2_req_data_valid   = w_fu_fifo_deq_ready[FU_LSU] &&
                                 !r_lsu_request_pending_vec[w_fu_fifo_head_data[FU_LSU].thrd_id] &&
                                 !r_lsu_resp_valid_vec[w_fu_fifo_head_data[FU_LSU].thrd_id] &&
                                 !r_lsu_pf_valid_vec[w_fu_fifo_head_data[FU_LSU].thrd_id];
        w_fu_fifo_deq_valid[FU_ALU] =
            (!w_alu_fifo_head_data.valid[0] || w_alu_fifo_head_data.instr[0].instr.is_page_fault ||
             (w_alu_req_valid[0] && w_alu_req_ready[0])) &&
            (!w_alu_fifo_head_data.valid[1] || w_alu_fifo_head_data.instr[1].instr.is_page_fault ||
             (w_alu_req_valid[1] && w_alu_req_ready[1]));
        w_fu_fifo_deq_valid[FU_FPU] = w_fu_fifo_head_data[FU_FPU].instr.is_page_fault ||
                                       (w_fpu_req_valid && w_fpu_req_ready);
        w_fu_fifo_deq_valid[FU_LSU] = o_req_data_valid && i_req_data_ready;
        w_fu_fifo_deq_valid[FU_MCU] = w_fu_fifo_deq_ready[FU_MCU];
        w_fu_fifo_deq_valid[FU_CSR] = w_fu_fifo_deq_ready[FU_CSR];
    end
    assign w_alu_issued_instr = s0_p2_alu_issued_instr;
    assign w_alu_req_valid    = s0_p2_alu_req_valid;
    assign w_fpu_issued_instr = s0_p2_fpu_issued_instr;
    assign w_fpu_req_valid    = s0_p2_fpu_req_valid;
    assign o_req_data_addr    = s0_p2_req_data_addr;
    assign o_req_data_thrd_id = s0_p2_req_data_thrd_id;
    assign o_req_data_priv    = s0_p2_req_data_priv;
    assign o_req_data_rw      = s0_p2_req_data_rw;
    assign o_req_data_wstrb   = s0_p2_req_data_wstrb;
    assign o_req_data_wdata   = s0_p2_req_data_wdata;
    assign o_req_data_lq      = s0_p2_req_data_lq;
    assign o_req_data_sc      = s0_p2_req_data_sc;
    assign o_req_data_valid   = s0_p2_req_data_valid;
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_commit_last_thrd_id <= '0;
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                r_lsu_resp_valid_vec[i]      <= 1'b0;
                r_lsu_resp_rdata_vec[i]      <= '0;
                r_lsu_resp_sc_ok_vec[i]      <= 1'b0;
                r_lsu_pf_valid_vec[i]        <= 1'b0;
                r_lsu_request_pending_vec[i] <= 1'b0;
            end
        end else begin
            if (w_ififo_deq_valid && w_ififo_deq_ready) begin
                r_commit_last_thrd_id <= w_commit_thrd_id;
                if (w_ififo_head_data.instr.fu == FU_LSU) begin
                    r_lsu_resp_valid_vec[w_commit_thrd_id] <= 1'b0;
                    r_lsu_pf_valid_vec[w_commit_thrd_id]   <= 1'b0;
                end
            end
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (w_fast_commit_vec[i] && r_rob_instr[i].instr.fu == FU_LSU)
                    r_lsu_resp_valid_vec[i] <= 1'b0;
            end
            if (i_resp_data_valid && o_resp_data_ready) begin
                r_lsu_request_pending_vec[i_resp_data_thrd_id] <= 1'b0;
                r_lsu_resp_valid_vec[i_resp_data_thrd_id]      <= 1'b1;
                r_lsu_resp_rdata_vec[i_resp_data_thrd_id]      <= i_resp_data_rdata;
                r_lsu_resp_sc_ok_vec[i_resp_data_thrd_id]      <= i_resp_data_sc_ok;
            end
            if (i_page_msg_data_valid && o_page_msg_data_ready &&
                s3_p0_fe_page_msg_data.msg_type == PAGE_MSG_FAULT) begin
                r_lsu_request_pending_vec[s1_p0_pf_msg_data.thrd_id[$clog2(NUM_HW_THRDS)-1:0]] <= 1'b0;
                r_lsu_pf_valid_vec[s1_p0_pf_msg_data.thrd_id[$clog2(NUM_HW_THRDS)-1:0]]        <= 1'b1;
            end
            if (o_req_data_valid && i_req_data_ready)
                r_lsu_request_pending_vec[o_req_data_thrd_id] <= 1'b1;
        end
    end

    // ...

    /* ---s0 */
    /*  ---Dispatch */



    /* 3. Commit---  */
    /* s0--- */
    // public s1_*
    // ...

    // private s0_*
    logic [XLEN-1:0]                        s0_p3_lsu_rdata;
    logic [XLEN-1:0]                        s0_p3_lsu_shifted;
    logic [VIR_ADDR_W-1:0]                  s0_p3_lsu_addr;
    logic                                   s0_p3_is_data_pf;
    logic                                   s0_p3_is_trap;
    logic                                   s0_p3_commit_csr_write;
    logic [$clog2(CSR_COUNT)-1:0]           s0_p3_commit_csr_addr;
    logic                                   s0_p3_is_page_msg_cmd;
    logic [XLEN-1:0]                        s0_p3_page_msg_cmd_val;
    logic                                   s0_p3_is_vtid_update;
    logic [XLEN-1:0]                        s0_p3_vtid_update_val;
    logic                                   s0_p3_stall_commit_for_tlb;
    logic [XLEN-1:0]                        s0_p3_page_msg_arg0         [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        s0_p3_page_msg_arg1         [NUM_HW_THRDS-1:0];

    // s0 combinational logic
    assign s0_p3_lsu_addr    = w_ififo_head_data.rs1_data + w_ififo_head_data.instr.imm;
    assign s0_p3_lsu_shifted = r_lsu_resp_rdata_vec[w_commit_thrd_id] >> (s0_p3_lsu_addr[$clog2(XLEN/8)-1:0] * 8);

    always_comb begin
        case (w_ififo_head_data.instr.ls_op)
            LS_LOAD_I8:  s0_p3_lsu_rdata = {{(XLEN-8){s0_p3_lsu_shifted[7]}},   s0_p3_lsu_shifted[7:0]};
            LS_LOAD_U8:  s0_p3_lsu_rdata = {{(XLEN-8){1'b0}},                   s0_p3_lsu_shifted[7:0]};
            LS_LOAD_I16: s0_p3_lsu_rdata = {{(XLEN-16){s0_p3_lsu_shifted[15]}}, s0_p3_lsu_shifted[15:0]};
            LS_LOAD_U16: s0_p3_lsu_rdata = {{(XLEN-16){1'b0}},                  s0_p3_lsu_shifted[15:0]};
            LS_LOAD_I32: s0_p3_lsu_rdata = {{(XLEN-32){s0_p3_lsu_shifted[31]}}, s0_p3_lsu_shifted[31:0]};
            LS_LOAD_U32: s0_p3_lsu_rdata = {{(XLEN-32){1'b0}},                  s0_p3_lsu_shifted[31:0]};
            LS_LOAD_I64: s0_p3_lsu_rdata = s0_p3_lsu_shifted;
            LS_CSTORE_8,  LS_CSTORE_8_RL,
            LS_CSTORE_16, LS_CSTORE_16_RL,
            LS_CSTORE_32, LS_CSTORE_32_RL,
            LS_CSTORE_64, LS_CSTORE_64_RL: s0_p3_lsu_rdata = {{(XLEN-1){1'b0}}, !r_lsu_resp_sc_ok_vec[w_commit_thrd_id]};
            default:     s0_p3_lsu_rdata = r_lsu_resp_rdata_vec[w_commit_thrd_id];
        endcase
    end

    assign w_regfile_rd_addr    = w_ififo_head_data.instr.rd;
    assign w_regfile_rd_wdata   = w_ififo_head_data.instr.fu == FU_ALU ?
                                  (w_alu_res_thrd_id[0] == w_commit_thrd_id ? w_alu_result[0] : w_alu_result[1]) :
                                  w_ififo_head_data.instr.fu == FU_CSR ? w_ififo_head_data.csr_data :
                                  w_ififo_head_data.instr.fu == FU_FPU ? w_fpu_result               :
                                  w_ififo_head_data.instr.fu == FU_LSU ? s0_p3_lsu_rdata            :
                                  '0;
    assign s0_p3_csr_operand    = w_ififo_head_data.instr.use_imm ?
                                  {{(XLEN-REG_BITS){1'b0}}, w_ififo_head_data.instr.rs1} :
                                  w_ififo_head_data.rs1_data;

    always_comb begin
        unique case (w_ififo_head_data.instr.funct3)
            3'b010,
            3'b110:  w_csr_rd_wdata = w_ififo_head_data.csr_data | s0_p3_csr_operand;
            3'b011,
            3'b111:  w_csr_rd_wdata = w_ififo_head_data.csr_data & ~s0_p3_csr_operand;
            default: w_csr_rd_wdata = s0_p3_csr_operand;
        endcase
    end
    assign s0_p3_is_data_pf     = w_ififo_deq_ready && (w_ififo_head_data.instr.fu == FU_LSU) &&
                                  r_lsu_pf_valid_vec[w_commit_thrd_id];
    assign s0_p3_is_trap        = w_ififo_head_data.instr.is_ecall || w_ififo_head_data.instr.is_page_fault || s0_p3_is_data_pf;
    assign w_csr_trap_we        = w_ififo_deq_valid && w_ififo_deq_ready && s0_p3_is_trap;
    assign w_csr_trap_mepc      = w_ififo_head_data.instr.pc;
    assign w_csr_trap_to_s      = w_ififo_head_data.trap_to_s;

    always_comb begin
        w_csr_trap_tval = '0;
        if (s0_p3_is_data_pf) begin
            w_csr_trap_tval = XLEN'(s0_p3_lsu_addr);
        end else if (w_ififo_head_data.instr.is_page_fault && w_ififo_head_data.instr.trap_cause == isa_pkg::TRAP_CAUSE_INST_PAGE_FAULT) begin
            w_csr_trap_tval = w_ififo_head_data.instr.pc;
        end
    end

    always_comb begin
        if (w_ififo_head_data.instr.is_page_fault) begin
            if (w_ififo_head_data.instr.trap_cause[isa_pkg::TRAP_CAUSE_W-1]) begin
                if (w_ififo_head_data.trap_to_s &&
                    w_ififo_head_data.instr.trap_cause == isa_pkg::IRQ_CAUSE_MACHINE_TIMER) begin
                    w_csr_trap_mcause = {1'b1, {(XLEN-isa_pkg::TRAP_CAUSE_W){1'b0}},
                                         isa_pkg::IRQ_CAUSE_SUPERVISOR_TIMER[isa_pkg::TRAP_CAUSE_W-2:0]};
                end else begin
                    w_csr_trap_mcause = {1'b1, {(XLEN-isa_pkg::TRAP_CAUSE_W){1'b0}},
                                         w_ififo_head_data.instr.trap_cause[isa_pkg::TRAP_CAUSE_W-2:0]};
                end
            end else begin
                w_csr_trap_mcause = XLEN'(w_ififo_head_data.instr.trap_cause);
            end
        end else if (s0_p3_is_data_pf) begin
            w_csr_trap_mcause = w_ififo_head_data.instr.ls_wen ? XLEN'(isa_pkg::TRAP_CAUSE_STORE_PAGE_FAULT) : XLEN'(isa_pkg::TRAP_CAUSE_LOAD_PAGE_FAULT);
        end else begin
            case (w_csr_priv_mode_vec[w_ififo_head_data.thrd_id])
                isa_pkg::PRIV_MODE_U: w_csr_trap_mcause = XLEN'(isa_pkg::TRAP_CAUSE_ECALL_U);
                isa_pkg::PRIV_MODE_S: w_csr_trap_mcause = XLEN'(isa_pkg::TRAP_CAUSE_ECALL_S);
                default:              w_csr_trap_mcause = XLEN'(isa_pkg::TRAP_CAUSE_ECALL_M);
            endcase
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            s1_p0_backend_fb_npc[i]   = r_rob_instr[i].instr.pc + VIR_ADDR_W'(INST_W / 8);
            s1_p0_backend_fb_valid[i] = 1'b0;
            s1_p0_backend_fb_redirect[i]   = 1'b0;
        end
        if (w_commit_found) begin
            s1_p0_backend_fb_npc[w_ififo_head_data.thrd_id] =
                s0_p3_is_trap ? trap_vector_addr(w_ififo_head_data.csr_data, w_csr_trap_mcause) :
                (w_ififo_head_data.instr.is_sret || w_ififo_head_data.instr.is_mret) ? w_ififo_head_data.csr_data :
                (w_ififo_head_data.instr.fu == FU_ALU && (w_ififo_head_data.instr.is_jump ||
                (w_ififo_head_data.instr.is_branch &&
                 (w_alu_res_thrd_id[0] == w_commit_thrd_id ? w_alu_br_taken[0] : w_alu_br_taken[1])))) ?
                (w_alu_res_thrd_id[0] == w_commit_thrd_id ? w_alu_br_target[0] : w_alu_br_target[1]) :
                (w_ififo_head_data.instr.pc + VIR_ADDR_W'(INST_W / 8));
            s1_p0_backend_fb_valid[w_ififo_head_data.thrd_id] =
                w_ififo_deq_valid && w_ififo_deq_ready && !s0_p3_stall_commit_for_tlb;
            s1_p0_backend_fb_redirect[w_ififo_head_data.thrd_id] =
                s0_p3_is_trap || w_ififo_head_data.instr.is_sret ||
                w_ififo_head_data.instr.is_mret || w_ififo_head_data.instr.is_branch ||
                w_ififo_head_data.instr.is_jump;
        end
    end
    assign w_csr_wthrd_id             = w_ififo_head_data.thrd_id;
    assign w_regfile_wthrd_id         = w_ififo_head_data.thrd_id;
    assign w_regfile_we               = w_ififo_deq_valid && w_ififo_deq_ready && w_ififo_head_data.instr.rf_wen;
    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            automatic logic [VIR_ADDR_W-1:0] fast_lsu_addr = r_rob_instr[i].rs1_data + r_rob_instr[i].instr.imm;
            automatic logic [XLEN-1:0] fast_lsu_shifted = r_lsu_resp_rdata_vec[i] >> (fast_lsu_addr[$clog2(XLEN/8)-1:0] * 8);
            automatic logic [XLEN-1:0] fast_lsu_rdata;
            case (r_rob_instr[i].instr.ls_op)
                LS_LOAD_I8:  fast_lsu_rdata = {{(XLEN-8){fast_lsu_shifted[7]}},   fast_lsu_shifted[7:0]};
                LS_LOAD_U8:  fast_lsu_rdata = {{(XLEN-8){1'b0}},                 fast_lsu_shifted[7:0]};
                LS_LOAD_I16: fast_lsu_rdata = {{(XLEN-16){fast_lsu_shifted[15]}}, fast_lsu_shifted[15:0]};
                LS_LOAD_U16: fast_lsu_rdata = {{(XLEN-16){1'b0}},                 fast_lsu_shifted[15:0]};
                LS_LOAD_I32: fast_lsu_rdata = {{(XLEN-32){fast_lsu_shifted[31]}}, fast_lsu_shifted[31:0]};
                LS_LOAD_U32: fast_lsu_rdata = {{(XLEN-32){1'b0}},                 fast_lsu_shifted[31:0]};
                LS_LOAD_I64: fast_lsu_rdata = fast_lsu_shifted;
                LS_CSTORE_8,  LS_CSTORE_8_RL,
                LS_CSTORE_16, LS_CSTORE_16_RL,
                LS_CSTORE_32, LS_CSTORE_32_RL,
                LS_CSTORE_64, LS_CSTORE_64_RL: fast_lsu_rdata = {{(XLEN-1){1'b0}}, !r_lsu_resp_sc_ok_vec[i]};
                default: fast_lsu_rdata = r_lsu_resp_rdata_vec[i];
            endcase
            w_regfile_we_vec[i]       = 1'b0;
            w_regfile_rd_addr_vec[i]  = '0;
            w_regfile_rd_wdata_vec[i] = '0;
            if (w_fast_commit_vec[i] && r_rob_instr[i].instr.rf_wen) begin
                w_regfile_we_vec[i]      = 1'b1;
                w_regfile_rd_addr_vec[i] = r_rob_instr[i].instr.rd;
                case (r_rob_instr[i].instr.fu)
                    FU_ALU: w_regfile_rd_wdata_vec[i] =
                        w_alu_res_thrd_id[0] == i[$clog2(NUM_HW_THRDS)-1:0] ? w_alu_result[0] : w_alu_result[1];
                    FU_FPU: w_regfile_rd_wdata_vec[i] = w_fpu_result;
                    FU_LSU: w_regfile_rd_wdata_vec[i] = fast_lsu_rdata;
                    default: w_regfile_rd_wdata_vec[i] = '0;
                endcase
            end
        end
        if (w_regfile_we) begin
            w_regfile_we_vec[w_regfile_wthrd_id]       = 1'b1;
            w_regfile_rd_addr_vec[w_regfile_wthrd_id]  = w_regfile_rd_addr;
            w_regfile_rd_wdata_vec[w_regfile_wthrd_id] = w_regfile_rd_wdata;
        end
    end
    assign w_csr_we                   = w_ififo_deq_valid && w_ififo_deq_ready && w_ififo_head_data.instr.csr_wen;
    assign s0_p3_commit_csr_write     = w_ififo_deq_valid && w_ififo_deq_ready && (w_ififo_head_data.instr.csr_wen || w_ififo_head_data.instr.is_ecall);
    assign s0_p3_commit_csr_addr      = w_ififo_head_data.instr.is_ecall ? core_pkg::CSR_MEPC :  csr_addr_decode(w_ififo_head_data.instr.imm[isa_pkg::CSR_ADDR_W-1:0]);
    assign s0_p3_is_page_msg_cmd      = s0_p3_commit_csr_write && (s0_p3_commit_csr_addr == core_pkg::CSR_PAGE_MSG_CMD);
    assign s0_p3_page_msg_cmd_val     = w_csr_rd_wdata[XLEN-1:0];
    assign s0_p3_is_vtid_update       = s0_p3_commit_csr_write && (s0_p3_commit_csr_addr == core_pkg::CSR_VIRTUAL_THRD_ID);
    assign s0_p3_vtid_update_val      = w_csr_rd_wdata[XLEN-1:0];
    assign o_page_msg_valid           = s0_p3_is_page_msg_cmd || s0_p3_is_vtid_update;
    assign s0_p3_stall_commit_for_tlb = (s0_p3_is_page_msg_cmd || s0_p3_is_vtid_update) && !i_page_msg_ready;


    for (genvar i = 0; i < 2; i++) begin: gen_alu_res_ready
        assign w_alu_res_ready[i] = w_fast_commit_vec[w_alu_res_thrd_id[i]] ||
                                    (w_commit_found && w_ififo_head_data.instr.fu == FU_ALU &&
                                     w_ififo_head_data.thrd_id == w_alu_res_thrd_id[i]) ||
                                    !r_rob_valid[w_alu_res_thrd_id[i]];
    end
    assign w_fpu_res_ready            = w_fast_commit_vec[w_fpu_res_thrd_id] ||
                                        (w_commit_found && w_ififo_head_data.instr.fu == FU_FPU);
    assign o_resp_data_ready          = !r_lsu_resp_valid_vec[i_resp_data_thrd_id] ||
                                        w_fast_commit_vec[i_resp_data_thrd_id] ||
                                        (w_ififo_deq_valid && w_ififo_deq_ready &&
                                         w_ififo_head_data.instr.fu == FU_LSU &&
                                         i_resp_data_thrd_id == w_commit_thrd_id);
    assign w_csr_mret_we              = w_ififo_deq_valid && w_ififo_deq_ready && w_ififo_head_data.instr.is_mret;
    assign w_csr_sret_we              = w_ififo_deq_valid && w_ififo_deq_ready && w_ififo_head_data.instr.is_sret;

    always_comb begin
        if (s0_p3_is_vtid_update) begin
            automatic vtid_update_msg_t msg;
            msg          = '0;
            msg.msg_type = PAGE_MSG_VTID_UPDATE;
            msg.thrd_id  = i_thrd_id_vec[w_csr_wthrd_id][THRD_W-1:0];
            msg.vtid     = s0_p3_vtid_update_val[VTID_W-1:0];
            o_page_msg   = msg;
        end else begin
            automatic logic [XLEN-1:0] cmd_val = s0_p3_page_msg_cmd_val;
            automatic logic [XLEN-1:0] arg0    = s0_p3_page_msg_arg0[w_ififo_head_data.thrd_id];
            automatic logic [XLEN-1:0] arg1    = s0_p3_page_msg_arg1[w_ififo_head_data.thrd_id];
            
            if (cmd_val[$bits(page_msg_type_e)-1:0] == PAGE_MSG_TLB_UPDATE) begin
                automatic tlb_update_msg_t msg;
                msg          = '0;
                msg.msg_type = PAGE_MSG_TLB_UPDATE;
                msg.vpn      = arg0[XLEN-1:$clog2(memory_pkg::PAGE_SIZE)];
                msg.user_acc = arg0[$clog2(memory_pkg::PAGE_SIZE)-1];
                msg.writable = arg0[$clog2(memory_pkg::PAGE_SIZE)-2];
                msg.vtid     = VTID_W'(arg0[TLB_UPDATE_VTID_ARG_W-1:0]);
                msg.ppn      = arg1[PPN_W-1:0];
                o_page_msg   = msg;
            end else begin
                automatic page_transfer_msg_t msg;
                msg          = '0;
                msg.msg_type = page_msg_type_e'(cmd_val[$bits(page_msg_type_e)-1:0]);
                msg.thrd_id  = THRD_W'(i_thrd_id_vec[w_ififo_head_data.thrd_id]);
                msg.axi_addr = arg0[XLEN-1:0];
                msg.ppn      = arg1[PPN_W-1:0];
                o_page_msg   = msg;
            end
        end
    end

    always_ff @(posedge i_clk) begin: s0_p3_page_msg_args
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                s0_p3_page_msg_arg0[i] <= '0;
                s0_p3_page_msg_arg1[i] <= '0;
            end
        end else begin
            if (w_csr_we && (w_csr_rd_addr == core_pkg::CSR_PAGE_MSG_ARG0))
                s0_p3_page_msg_arg0[w_csr_wthrd_id] <= w_csr_rd_wdata;
            if (w_csr_we && (w_csr_rd_addr == core_pkg::CSR_PAGE_MSG_ARG1))
                s0_p3_page_msg_arg1[w_csr_wthrd_id] <= w_csr_rd_wdata;
        end
    end
    // ...
    /* ---s0 */
    /*  ---Commit */


    /* 4. Scoreboarding---  */
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                r_scb[i]                <= '0;
                r_csr_scb[i]            <= '0;
            end
        end else begin
            /* Architectural register scoreboard:
             *   mark on FU queue and ROB allocation
             *   clear on commit */
            for (int i = 0; i < FU_COUNT; i++) begin
                if (w_fu_fifo_enq_fire[i] && w_fu_fifo_enq_data[i].instr.rd != '0)
                    r_scb[w_fu_fifo_enq_data[i].thrd_id][w_fu_fifo_enq_data[i].instr.rd] <= 1'b1;
                if (i == FU_ALU && w_fu_fifo_enq_fire[i] && w_alu_fifo_lane_1_valid &&
                    w_alu_fifo_enq_data.instr[1].instr.rd != '0)
                    r_scb[w_alu_fifo_lane_1_thrd_id][w_alu_fifo_enq_data.instr[1].instr.rd] <= 1'b1;
            end
            for (int i = 0; i < NUM_HW_THRDS; i++) begin
                if (w_commit_valid_vec[i])
                    r_scb[i][r_rob_instr[i].instr.rd] <= 1'b0;
            end

            /* CSR scoreboard:
             *   mark on FU queue and ROB allocation
             *   clear at commit */
            for (int i = 0; i < FU_COUNT; i++) begin
                if (w_fu_fifo_enq_fire[i]) begin
                    automatic issue_instr_t issuei = w_fu_fifo_enq_data[i];
                    if (issuei.instr.csr_wen)
                        r_csr_scb[issuei.thrd_id][csr_addr_decode(issuei.instr.imm[isa_pkg::CSR_ADDR_W-1:0])] <= 1'b1;
                    if (issuei.instr.is_ecall) begin
                        r_csr_scb[issuei.thrd_id][core_pkg::CSR_MEPC]   <= 1'b1;
                        r_csr_scb[issuei.thrd_id][core_pkg::CSR_MCAUSE] <= 1'b1;
                    end
                end
            end
            if (s0_p3_commit_csr_write) begin
                r_csr_scb[w_ififo_head_data.thrd_id][s0_p3_commit_csr_addr] <= 1'b0;
                if (s0_p3_is_trap) begin
                    r_csr_scb[w_ififo_head_data.thrd_id][core_pkg::CSR_MCAUSE] <= 1'b0;
                end
            end
        end
    end
    /*  ---Scoreboarding */
endmodule: core
