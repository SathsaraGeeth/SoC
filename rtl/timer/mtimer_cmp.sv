/*
 * mtimer_cmp.sv
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


`timescale 1ps/1ps
`default_nettype none

import  mtimer_cmp_pkg::*;

module mtimer_cmp #(
    parameter BASE_ADDR = 64'h0
)(
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic                            i_req_we,
    input  logic [THRD_W-1:0]               i_req_thrd,
    input  logic                            i_req_is_lr,
    input  logic                            i_req_is_sc,
    input  logic [VIR_ADDR_W-1:0]           i_req_addr,
    input  logic [XLEN/8-1:0]               i_req_wstrb,
    input  logic [XLEN-1:0]                 i_req_wdata,
    input  logic                            i_req_valid,
    input  logic [PRIV_MODE_W-1:0]          i_req_priv,
    output logic                            o_req_ready,
    output logic [THRD_W-1:0]               o_resp_thrd,
    output logic                            o_resp_sc_succ,
    output logic [XLEN-1:0]                 o_resp_rdata,
    output logic                            o_resp_valid,
    input  logic                            i_resp_ready,
    output logic                            o_irq
);
    /* MMIO regs---  */
    logic [XLEN-1:0] r_mtime;
    logic [XLEN-1:0] r_mtimecmp;
    /*  ---MMIO regs */

    /* register the request---  */
    mtimer_cmp_pkg::reg_t   r_req_type;
    logic                   r_req_we;
    logic [XLEN-1:0]        r_req_wdata;
    logic [XLEN/8-1:0]      r_req_wstrb;
    priv_mode_e             r_req_priv;
    logic                   r_req_valid;
    logic [THRD_W-1:0]      r_req_thrd;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_req_type   <= mtimer_cmp_pkg::ILLEGAL;
            r_req_we     <= '0;
            r_req_wdata  <= '0;
            r_req_wstrb  <= '0;
            r_req_priv   <= PRIV_MODE_M;
            r_req_valid  <= '0;
            r_req_thrd   <= '0;
        end else begin
            if (i_req_valid && o_req_ready) begin
                r_req_type   <= mtimer_cmp_pkg::decode_reg(i_req_addr-BASE_ADDR);
                r_req_we     <= i_req_we;
                r_req_wdata  <= i_req_wdata;
                r_req_wstrb  <= i_req_wstrb;
                r_req_priv   <= priv_mode_e'(i_req_priv);
                r_req_valid  <= 1'b1;
                r_req_thrd   <= i_req_thrd;
            end else begin
                r_req_valid  <= 1'b0;
            end
        end
    end
    /* ---register the request */

    /* mtime---  */
    always_ff @(posedge i_clk) begin: mtime
        if (!i_rst_n) begin
            r_mtime <= '0;
        end else begin
            r_mtime <= r_mtime + 1'b1;
        end
    end: mtime
    /*  ---mtime */

    /* MMIO writes---  */
    always_ff @(posedge i_clk) begin: mtimer_cmp_write
        if (!i_rst_n) begin
            r_mtimecmp <= '1;
        end else if (r_req_we && (r_req_priv != PRIV_MODE_U) && r_req_valid) begin
            unique case (r_req_type)
                MTIMECMP: r_mtimecmp <= r_req_wdata;
                default begin
                end
            endcase
        end
    end: mtimer_cmp_write
    /*  ---MMIO writes */

    /* MMIO response---  */
    logic r_resp_busy;
    always_ff @(posedge i_clk) begin: mmio_response
        if (!i_rst_n) begin
            r_resp_busy    <= 1'b0;
            o_resp_thrd    <= '0;
            o_resp_sc_succ <= 1'b0;
            o_resp_rdata   <= '0;
            o_resp_valid   <= 1'b0;
        end else begin
            if (r_req_valid) begin
                r_resp_busy    <= 1'b1;
                o_resp_thrd    <= r_req_thrd;
                o_resp_sc_succ <= 1'b0;
                o_resp_valid   <= 1'b1;
                unique case (r_req_type)
                    MTIME:    o_resp_rdata <= r_mtime;
                    MTIMECMP: o_resp_rdata <= r_mtimecmp;
                    default:  o_resp_rdata <= '0;
                endcase
            end
            if (o_resp_valid && i_resp_ready) begin
                r_resp_busy  <= 1'b0;
                o_resp_valid <= 1'b0;
            end
        end
    end: mmio_response

    assign o_req_ready = !r_resp_busy && !r_req_valid;
    /*  ---MMIO response */

    /* irq---  */
    assign o_irq = r_mtime >= r_mtimecmp;
    /*  ---irq */
endmodule: mtimer_cmp

`default_nettype wire
