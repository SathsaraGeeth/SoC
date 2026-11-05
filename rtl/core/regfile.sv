/*
 * regfile.sv
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
 * 1. No forwarding
 * 2. Each bank has #NUM_HW_THRDS registers each memory is from a distinct thread, so no conflicts
 */

`timescale 1ns/1ps
`default_nettype none
import core_pkg::*;

module regfile (
    input  logic                            i_clk,
    input  logic                            i_we,
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs1_addr,
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs2_addr,
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs3_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_rthrd_id,
    input  logic [$clog2(REG_COUNT)-1:0]    i_rd_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_wthrd_id,
    input  logic [XLEN-1:0]                 i_rd_wdata,
    output logic [XLEN-1:0]                 o_rs1_data,
    output logic [XLEN-1:0]                 o_rs2_data,
    output logic [XLEN-1:0]                 o_rs3_data
);
    logic [$clog2(REG_COUNT)-1:0] r_rs1_addr;
    logic [$clog2(REG_COUNT)-1:0] r_rs2_addr;
    logic [$clog2(REG_COUNT)-1:0] r_rs3_addr;
    logic [XLEN-1:0]              w_out [REG_COUNT-1:0];

    always_ff @(posedge i_clk) begin
        r_rs1_addr <= i_rs1_addr;
        r_rs2_addr <= i_rs2_addr;
        r_rs3_addr <= i_rs3_addr;
    end

    assign w_out[0]   = '0; // x0 is always 0
    assign o_rs1_data = w_out[r_rs1_addr];
    assign o_rs2_data = w_out[r_rs2_addr];
    assign o_rs3_data = w_out[r_rs3_addr];
    genvar i;
    for (i = 1; i < REG_COUNT; i++) begin : gen_banks
        mem_bank bank (
            .i_clk      (i_clk),
            .i_raddr    (i_rthrd_id),
            .i_waddr    (i_wthrd_id),
            .i_wen      (i_we && (i_rd_addr == i)),
            .o_rdata    (w_out[i]),
            .o_rdata_vec(),
            .i_wdata    (i_rd_wdata)
        );
    end
endmodule: regfile


module threaded_regfile (
    input  logic                            i_clk,
    input  logic                            i_we       [NUM_HW_THRDS-1:0],
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs1_addr [NUM_HW_THRDS-1:0],
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs2_addr [NUM_HW_THRDS-1:0],
    input  logic [$clog2(REG_COUNT)-1:0]    i_rs3_addr [NUM_HW_THRDS-1:0],
    input  logic [$clog2(REG_COUNT)-1:0]    i_rd_addr  [NUM_HW_THRDS-1:0],
    input  logic [XLEN-1:0]                 i_rd_wdata [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_rs1_data [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_rs2_data [NUM_HW_THRDS-1:0],
    output logic [XLEN-1:0]                 o_rs3_data [NUM_HW_THRDS-1:0]
);
    logic [$clog2(REG_COUNT)-1:0] r_rs1_addr [NUM_HW_THRDS-1:0];
    logic [$clog2(REG_COUNT)-1:0] r_rs2_addr [NUM_HW_THRDS-1:0];
    logic [$clog2(REG_COUNT)-1:0] r_rs3_addr [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]              mem        [NUM_HW_THRDS-1:0] [REG_COUNT-1:1];

    always_ff @(posedge i_clk) begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            r_rs1_addr[i] <= i_rs1_addr[i];
            r_rs2_addr[i] <= i_rs2_addr[i];
            r_rs3_addr[i] <= i_rs3_addr[i];
            if (i_we[i] && i_rd_addr[i] != '0) begin
                mem[i][i_rd_addr[i]] <= i_rd_wdata[i];
            end
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_HW_THRDS; i++) begin
            o_rs1_data[i] = r_rs1_addr[i] == '0 ? '0 : mem[i][r_rs1_addr[i]];
            o_rs2_data[i] = r_rs2_addr[i] == '0 ? '0 : mem[i][r_rs2_addr[i]];
            o_rs3_data[i] = r_rs3_addr[i] == '0 ? '0 : mem[i][r_rs3_addr[i]];
        end
    end
endmodule: threaded_regfile

module mem_bank (
    input  logic                              i_clk,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]   i_raddr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]   i_waddr,
    input  logic                              i_wen,
    output logic [XLEN-1:0]                   o_rdata,
    output logic [XLEN-1:0]                   o_rdata_vec [NUM_HW_THRDS-1:0],
    input  logic [XLEN-1:0]                   i_wdata
);
    logic [XLEN-1:0] mem [NUM_HW_THRDS-1:0];

    assign o_rdata_vec = mem;

    always_ff @(posedge i_clk) begin
        if (i_wen) begin
            mem[i_waddr] <= i_wdata;
        end
        o_rdata <= mem[i_raddr];
    end
endmodule: mem_bank
