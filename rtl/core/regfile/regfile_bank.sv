/*
 * reg_bank.sv
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
 * 1. 1r1w sram macro
 */

`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;

module regfile_bank #(
    parameter int REG_COUNT = 1024
)(
    input  logic                            i_clk,
    input  logic [$clog2(REG_COUNT)-1:0]    i_raddr,
    output logic [XLEN-1:0]                 o_rdata,
    input  logic                            i_we,
    input  logic [$clog2(REG_COUNT)-1:0]    i_waddr,
    input  logic [XLEN-1:0]                 i_wdata
);
    logic [XLEN-1:0] mem [REG_COUNT-1:0];

    always_ff @(posedge i_clk) begin
        if (i_we)
            mem[i_waddr] <= i_wdata;
        o_rdata <= mem[i_raddr];
    end
endmodule: regfile_bank

`default_nettype wire
