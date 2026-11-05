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
 * 1. Adressing is done address = thread_id * REG_COUNT + reg_id
 * 2. So for 32 regs and 32 threads, address space is 0-1023
 * 3. The ports dont differentiate between threads, or reg_id for flexibility
 * 4. The regfile is made from common 1r1w sram banks
 * 5. The time it takes to access/update a regfile is may be variable
 */

`timescale 1ns/1ps
`default_nettype none

import core_pkg::*;
import regfile_pkg::*;

module regfile (
    input  logic                            i_clk,
    input  logic                            i_rst_n,

    input  logic                            i_read_req_valid,
    output logic                            o_read_req_ready,
    input  reg_read_req_t                   i_read_req,
    output logic                            o_read_resp_valid,
    input  logic                            i_read_resp_ready,
    output reg_read_resp_t                  o_read_resp,

    input  logic                            i_write_req_valid,
    output logic                            o_write_req_ready,
    input  logic [REG_ADDR_W-1:0]           i_write_req_addr,
    input  logic [XLEN-1:0]                 i_write_req_wdata
);

    logic                   w_bank_clk   [2:0];
    logic  [REG_ADDR_W-1:0] w_bank_raddr [2:0];
    logic  [XLEN-1:0]       w_bank_rdata [2:0];
    logic                   w_bank_we    [2:0];
    logic  [REG_ADDR_W-1:0] w_bank_waddr [2:0];
    logic  [XLEN-1:0]       w_bank_wdata [2:0];


    for (genvar i = 0; i < 3; i++) begin: gen_read_operands
        regfile_bank #(
            .REG_COUNT(NUM_REGS)
        ) regfile_bank_u (
            .i_clk      (w_bank_clk  [i]),
            .i_raddr    (w_bank_raddr[i]),
            .o_rdata    (w_bank_rdata[i]),
            .i_we       (w_bank_we   [i]),
            .i_waddr    (w_bank_waddr[i]),
            .i_wdata    (w_bank_wdata[i])
        );
    end: gen_read_operands

    
    always_comb begin
        for (int i = 0; i < 3; i++) begin
            w_bank_clk  [i]  = i_clk;
            w_bank_we   [i]  = i_write_req_valid && !is_zero_reg(i_write_req_addr);
            w_bank_waddr[i]  = i_write_req_addr;
            w_bank_wdata[i]  = i_write_req_wdata;
        end
        w_bank_raddr[0]      = i_read_req.rs1_addr;
        w_bank_raddr[1]      = i_read_req.rs2_addr;
        w_bank_raddr[2]      = i_read_req.rs3_addr;
        o_read_resp.rs1_data = w_bank_rdata[0];
        o_read_resp.rs2_data = w_bank_rdata[1];
        o_read_resp.rs3_data = w_bank_rdata[2];
    end

    assign o_read_req_ready  = 1'b1;
    assign o_write_req_ready = 1'b1;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_read_resp_valid <= 1'b0;
        end else begin
            o_read_resp_valid <= i_read_req_valid;
        end
    end

endmodule: regfile

`default_nettype wire

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

`default_nettype wire
