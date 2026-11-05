/*
 * csr.sv
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
 * 1. implements machine, supervisor, and user privilege state
 */


`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;
import isa_pkg::*;

module csr (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic                            i_we,
    input  logic [XLEN-1:0]                 i_thread_id_vec [NUM_HW_THRDS-1:0],
    /* interrupts */
    input  logic [NUM_HW_THRDS-1:0]         i_irq_timer_vec,
    output logic [NUM_HW_THRDS-1:0]         o_irq_pending_vec,
    /* normal */
    input  logic [$clog2(CSR_COUNT)-1:0]    i_rs1_addr_vec [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_rs1_data_vec [NUM_HW_THRDS-1:0],
    input  logic [$clog2(CSR_COUNT)-1:0]    i_rd_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_wthrd_id,
    input  logic [XLEN-1:0]                 i_rd_wdata,
    /* priv */
    input  logic                            i_trap_we,
    input  logic [XLEN-1:0]                 i_trap_mepc,
    input  logic [XLEN-1:0]                 i_trap_mcause,
    input  logic [XLEN-1:0]                 i_trap_tval,
    input  logic                            i_trap_to_s,
    input  logic                            i_mret_we,
    input  logic                            i_sret_we,
    output logic [isa_pkg::PRIV_MODE_W-1:0] o_priv_mode_vec [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_medeleg_vec   [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_mideleg_vec   [NUM_HW_THRDS-1:0]
);
    /**--- */
    logic [isa_pkg::PRIV_MODE_W-1:0]        r_priv          [NUM_HW_THRDS-1:0];     /* curr. priv. mode */
    logic [isa_pkg::PRIV_MODE_W-1:0]        r_mpp           [NUM_HW_THRDS-1:0];     /* prv. priv. mode */
    logic                                   r_mie           [NUM_HW_THRDS-1:0];     /* global interrupt enable */
    logic                                   r_mpie          [NUM_HW_THRDS-1:0];     /* prv. interrupt enable */
    logic                                   r_spp           [NUM_HW_THRDS-1:0];     /* prv. supervisor privilege */
    logic                                   r_sie           [NUM_HW_THRDS-1:0];     /* supervisor interrupt enable */
    logic                                   r_spie          [NUM_HW_THRDS-1:0];     /* prv. supervisor interrupt enable */

    logic                                   w_bank_clk      [CSR_COUNT-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_bank_raddr    [CSR_COUNT-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]        w_bank_waddr    [CSR_COUNT-1:0];
    logic                                   w_bank_we       [CSR_COUNT-1:0];
    logic [XLEN-1:0]                        w_bank_rdata_vec [CSR_COUNT-1:0][NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                        w_bank_wdata    [CSR_COUNT-1:0];

    genvar i;
    for (i = 0; i < CSR_COUNT; i++) begin: gen_banks
        localparam logic [$clog2(CSR_COUNT)-1:0] CSR_IDX = i[$clog2(CSR_COUNT)-1:0];
        always_comb begin
            w_bank_clk  [i] = i_clk;
            w_bank_raddr[i] = '0;
            w_bank_waddr[i] = i_wthrd_id;
            w_bank_we   [i] = i_we && (i_rd_addr == CSR_IDX);
            w_bank_wdata[i] = i_rd_wdata;
            /* ro */
            if (CSR_IDX == core_pkg::CSR_MSTATUS   || CSR_IDX == core_pkg::CSR_SSTATUS ||
                CSR_IDX == core_pkg::CSR_THREAD_ID || CSR_IDX == core_pkg::CSR_MIP     ||
                CSR_IDX == core_pkg::CSR_SIP) begin
                w_bank_we[i] = 1'b0;
            end
            /* trap */
            if (i_trap_we && !i_trap_to_s && CSR_IDX == core_pkg::CSR_MEPC) begin
                w_bank_we[i]    = 1'b1;
                w_bank_wdata[i] = i_trap_mepc;
            end else if (i_trap_we && !i_trap_to_s && CSR_IDX == core_pkg::CSR_MCAUSE) begin
                w_bank_we[i]    = 1'b1;
                w_bank_wdata[i] = i_trap_mcause;
            end else if (i_trap_we && i_trap_to_s && CSR_IDX == core_pkg::CSR_SEPC) begin
                w_bank_we[i]    = 1'b1;
                w_bank_wdata[i] = i_trap_mepc;
            end else if (i_trap_we && i_trap_to_s && CSR_IDX == core_pkg::CSR_SCAUSE) begin
                w_bank_we[i]    = 1'b1;
                w_bank_wdata[i] = i_trap_mcause;
            end else if (i_trap_we && i_trap_to_s && CSR_IDX == core_pkg::CSR_STVAL) begin
                w_bank_we[i]    = 1'b1;
                w_bank_wdata[i] = i_trap_tval;
            end
        end

        mem_bank bank (
            .i_clk      (w_bank_clk  [i]),
            .i_raddr    (w_bank_raddr[i]),
            .i_waddr    (w_bank_waddr[i]),
            .i_wen      (w_bank_we   [i]),
            .o_rdata    (),
            .o_rdata_vec(w_bank_rdata_vec[i]),
            .i_wdata    (w_bank_wdata[i])
        );
    end: gen_banks
    /* ---**/
    
    /* priv modes & interrupts --- */
    always_comb begin
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            o_priv_mode_vec[t]   = r_priv[t];
            o_irq_pending_vec[t] = i_irq_timer_vec[t] &
                                   (w_bank_rdata_vec[core_pkg::CSR_MIDELEG][t][CSR_MIE_MTIE_BIT] ?
                                   (w_bank_rdata_vec[core_pkg::CSR_SIE][t][CSR_MIE_MTIE_BIT] &&
                                   ((r_priv[t] == PRIV_MODE_U) || ((r_priv[t] == PRIV_MODE_S) && r_sie[t]))) :
                                   (w_bank_rdata_vec[core_pkg::CSR_MIE][t][CSR_MIE_MTIE_BIT] && ((r_priv[t] != PRIV_MODE_M) || r_mie[t])));
            o_medeleg_vec[t] = w_bank_rdata_vec[core_pkg::CSR_MEDELEG][t];
            o_mideleg_vec[t] = w_bank_rdata_vec[core_pkg::CSR_MIDELEG][t];
        end
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            unique case (i_rs1_addr_vec[t])
                core_pkg::CSR_MSTATUS:   o_rs1_data_vec[t] = csr_mstatus_from_fields(r_mpp[t], r_mpie[t], r_mie[t]);
                core_pkg::CSR_SSTATUS:   o_rs1_data_vec[t] = csr_sstatus_from_fields(r_spp[t], r_spie[t], r_sie[t]);
                core_pkg::CSR_MIP:       o_rs1_data_vec[t] = csr_mip_from_mtip(i_irq_timer_vec[t]);
                core_pkg::CSR_SIP:       o_rs1_data_vec[t] = '0;
                core_pkg::CSR_THREAD_ID: o_rs1_data_vec[t] = i_thread_id_vec[t];
                default:       o_rs1_data_vec[t] = w_bank_rdata_vec[i_rs1_addr_vec[t]][t];
            endcase
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            /* boot to machine mode */
            for (int t = 0; t < NUM_HW_THRDS; t++) begin
                r_priv[t] <= PRIV_MODE_M;
                r_mpp [t] <= PRIV_MODE_M;
                r_mie [t] <= 1'b0;
                r_mpie[t] <= 1'b0;
                r_spp [t] <= 1'b0;
                r_sie [t] <= 1'b0;
                r_spie[t] <= 1'b0;
            end
        end else begin
            if (i_trap_we && i_trap_to_s) begin
                r_spp [i_wthrd_id] <= r_priv[i_wthrd_id] == PRIV_MODE_S;
                r_spie[i_wthrd_id] <= r_sie[i_wthrd_id];
                r_sie [i_wthrd_id] <= 1'b0;
                r_priv[i_wthrd_id] <= PRIV_MODE_S;
            end else if (i_trap_we) begin
                r_mpp [i_wthrd_id] <= r_priv[i_wthrd_id];
                r_mpie[i_wthrd_id] <= r_mie[i_wthrd_id];
                r_mie [i_wthrd_id] <= 1'b0;
                r_priv[i_wthrd_id] <= PRIV_MODE_M;
            end else if (i_mret_we) begin
                r_priv[i_wthrd_id] <= r_mpp[i_wthrd_id];
                r_mpp [i_wthrd_id] <= PRIV_MODE_U;
                r_mie [i_wthrd_id] <= r_mpie[i_wthrd_id];
                r_mpie[i_wthrd_id] <= 1'b1;
            end else if (i_sret_we) begin
                r_priv[i_wthrd_id] <= r_spp[i_wthrd_id] ? PRIV_MODE_S : PRIV_MODE_U;
                r_spp [i_wthrd_id] <= 1'b0;
                r_sie [i_wthrd_id] <= r_spie[i_wthrd_id];
                r_spie[i_wthrd_id] <= 1'b1;
            end else if (i_we && (i_rd_addr == core_pkg::CSR_MSTATUS)) begin
                r_mpp [i_wthrd_id] <= csr_mstatus_mpp(i_rd_wdata);
                r_mie [i_wthrd_id] <= i_rd_wdata[CSR_MSTATUS_MIE_BIT];
                r_mpie[i_wthrd_id] <= i_rd_wdata[CSR_MSTATUS_MPIE_BIT];
            end else if (i_we && (i_rd_addr == core_pkg::CSR_SSTATUS)) begin
                r_spp [i_wthrd_id] <= i_rd_wdata[CSR_SSTATUS_SPP_BIT];
                r_sie [i_wthrd_id] <= i_rd_wdata[CSR_SSTATUS_SIE_BIT];
                r_spie[i_wthrd_id] <= i_rd_wdata[CSR_SSTATUS_SPIE_BIT];
            end
        end
    end
    /* ---priv modes & interrupts */
endmodule: csr
