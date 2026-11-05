/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

`default_nettype none

import memory_pkg::*;

module sram_bank_formal (
    input logic                         clk,
    input logic                         rst_n,
    input logic                         req_valid,
    input logic                         resp_expected,
    input logic                         resp_ready,
    input logic [PORT_IDX_W-1:0]        req_port,
    input logic [THRD_W-1:0]            req_thrd,
    input logic                         lr,
    input logic                         sc,
    input logic [BANK_ADDR_W-1:0]       raddr,
    input logic [BANK_ADDR_W-1:0]       waddr,
    input logic [BANK_WORD_W/8-1:0]     wstrb,
    input logic [XLEN-1:0]              wdata,
    input logic                         we
);
    logic req_ready;
    logic resp_valid;
    logic sc_succ;
    logic [PORT_IDX_W-1:0] resp_port;
    logic [THRD_W-1:0] resp_thrd;
    logic [XLEN-1:0] rdata;
    logic f_past_valid = 1'b0;

    sram_bank #(.BANK_IDX(0)) dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_req_valid(req_valid), .i_resp_expected(resp_expected),
        .o_req_ready(req_ready), .o_resp_valid(resp_valid),
        .i_resp_ready(resp_ready), .i_req_port(req_port),
        .i_req_thrd(req_thrd), .i_lr(lr), .i_sc(sc),
        .i_raddr(raddr), .i_waddr(waddr), .i_wstrb(wstrb),
        .i_wdata(wdata), .i_we(we), .o_sc_succ(sc_succ),
        .o_resp_port(resp_port), .o_resp_thrd(resp_thrd),
        .o_rdata(rdata)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "sram_bank_assumptions.sv"
    `include "sram_bank_reset.sv"
    `include "sram_bank_protocol.sv"
    `include "sram_bank_reservation.sv"
    `include "sram_bank_coverpoints.sv"
endmodule: sram_bank_formal

`default_nettype wire

