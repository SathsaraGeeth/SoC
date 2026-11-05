/*
 * csr_mem_bank.sv
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


`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;

module csr_mem_bank #(
    parameter int unsigned DEPTH = NUM_HW_THRDS * NUM_CSR_SLOTS,
    parameter int unsigned ADDR_W = $clog2(DEPTH)
) (
    input  logic                  i_clk,
    input  logic [ADDR_W-1:0]     i_raddr,
    input  logic [ADDR_W-1:0]     i_waddr,
    input  logic                  i_wen,
    output logic [XLEN-1:0]       o_rdata,
    input  logic [XLEN-1:0]       i_wdata
);
    logic [XLEN-1:0] mem [DEPTH-1:0];

    always_ff @(posedge i_clk) begin
        if (i_wen) mem[i_waddr] <= i_wdata;
        o_rdata <= mem[i_raddr];
    end
endmodule: csr_mem_bank

`default_nettype wire
