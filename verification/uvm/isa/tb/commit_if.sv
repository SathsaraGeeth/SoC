/* 
 * verification/uvm/isa/commit_if.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
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
 * 1. Only monitor/assert arch. states updates. (i.e. architectural commits)
 * 2. Bind to each core
 * 3. This interface is intentionally limited to architectural core state.
 * 4. The testbech only caary on the M-mode.
 */

`timescale 1ns/1ps

import core_pkg::*;

interface commit_if (
    input logic                             clk,
    input logic                             rst_n
);
    /* per thread */
    logic [core_pkg::VIR_ADDR_W-1:0]        commit_pc      [NUM_HW_THRDS-1:0];
    logic                                   commit_valid   [NUM_HW_THRDS-1:0];
    logic [core_pkg::VIR_ADDR_W-1:0]        rf_pc          [NUM_HW_THRDS-1:0];
    logic                                   rf_we          [NUM_HW_THRDS-1:0];
    logic [$clog2(core_pkg::REG_COUNT)-1:0] rf_we_addr     [NUM_HW_THRDS-1:0];
    logic [core_pkg::XLEN-1:0]              rf_we_data     [NUM_HW_THRDS-1:0];
    logic [core_pkg::VIR_ADDR_W-1:0]        csr_pc         [NUM_HW_THRDS-1:0];
    logic                                   csr_we         [NUM_HW_THRDS-1:0];
    logic [$clog2(core_pkg::CSR_COUNT)-1:0] csr_we_addr    [NUM_HW_THRDS-1:0];
    logic [core_pkg::XLEN-1:0]              csr_we_data    [NUM_HW_THRDS-1:0];
    logic [core_pkg::VIR_ADDR_W-1:0]        mem_pc         [NUM_HW_THRDS-1:0];
    logic                                   mem_req_we     [NUM_HW_THRDS-1:0];
    logic [core_pkg::VIR_ADDR_W-1:0]        mem_req_addr   [NUM_HW_THRDS-1:0];
    logic [core_pkg::XLEN-1:0]              mem_req_wdata  [NUM_HW_THRDS-1:0];
    logic [core_pkg::XLEN-1:0]              mem_req_wmask  [NUM_HW_THRDS-1:0];

endinterface: commit_if

/* 
 * bind to core 
 */
bind core commit_binder u_commit_binder (
    .clk(i_clk),
    .rst_n(i_rst_n)
);
