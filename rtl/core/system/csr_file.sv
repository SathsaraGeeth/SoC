/*
 * csr_file.sv
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
import csr_pkg::*;

module csr_regfile (
    input  logic                              i_clk,
    input  logic                              i_rst_n,
    input  logic                              i_read_req_valid,
    output logic                              o_read_req_ready,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]   i_read_req_thrd_id,
    input  csr_slot_e                         i_read_req_csr,
    output logic                              o_read_resp_valid,
    input  logic                              i_read_resp_ready,
    output logic [XLEN-1:0]                   o_read_resp_rdata,
    input  logic                              i_write_req_valid,
    output logic                              o_write_req_ready,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]   i_write_req_thrd_id,
    input  csr_slot_e                         i_write_req_csr,
    input  logic [XLEN-1:0]                   i_write_req_wdata
);
    /* *---  */
    logic                      w_bank_clk;
    logic [CSR_MEM_ADDR_W-1:0] w_bank_read_addr;
    logic [CSR_MEM_ADDR_W-1:0] w_bank_write_addr;
    logic                      w_bank_wen;
    logic [XLEN-1:0]           w_bank_read_data;
    logic [XLEN-1:0]           w_bank_write_data;
    
    localparam int unsigned CSR_MEM_DEPTH = NUM_HW_THRDS * NUM_CSR_SLOTS;
    localparam int unsigned CSR_MEM_ADDR_W = $clog2(CSR_MEM_DEPTH);

    csr_mem_bank #(
        .DEPTH   (CSR_MEM_DEPTH),
        .ADDR_W  (CSR_MEM_ADDR_W)
    ) csr_mem_bank_u (
        .i_clk   (w_bank_clk),
        .i_raddr (w_bank_read_addr),
        .i_waddr (w_bank_write_addr),
        .i_wen   (w_bank_wen),
        .o_rdata (w_bank_read_data),
        .i_wdata (w_bank_write_data)
    );
    /*  ---* */

    logic                      w_read_accept;

    always_comb begin
        w_bank_clk        = i_clk;
        w_bank_wen        = i_write_req_valid;
        w_bank_write_data = i_write_req_wdata;
        w_read_accept     = i_read_req_valid && o_read_req_ready;
        w_bank_read_addr  = flatten_csr_addr(i_read_req_thrd_id, i_read_req_csr);
        w_bank_write_addr = flatten_csr_addr(i_write_req_thrd_id, i_write_req_csr);
        o_read_req_ready  = !o_read_resp_valid || i_read_resp_ready;
        o_write_req_ready = 1'b1;
        o_read_resp_rdata = w_bank_read_data;
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_read_resp_valid <= 1'b0;
        end else if (o_read_req_ready) begin
            o_read_resp_valid <= w_read_accept;
        end
    end

endmodule: csr_regfile

`default_nettype wire
