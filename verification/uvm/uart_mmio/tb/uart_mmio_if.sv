/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

interface uart_mmio_if;
    logic        clk;
    logic        rst_n;
    logic        req_we;
    logic [2:0]  req_thrd;
    logic        req_is_lr;
    logic        req_is_sc;
    logic [63:0] req_addr;
    logic [7:0]  req_wstrb;
    logic [63:0] req_wdata;
    logic        req_valid;
    logic [1:0]  req_priv;
    logic        req_ready;
    logic [2:0]  resp_thrd;
    logic        resp_sc_succ;
    logic [63:0] resp_rdata;
    logic        resp_valid;
    logic        resp_ready;
    logic        rx;
    logic        tx;
endinterface: uart_mmio_if
