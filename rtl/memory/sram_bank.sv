/*
 * sram_bank.sv - SRAM bank module
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
 * 1. 1 cycle read and write.
 * 2. 1r1w
 * 3. locks
 * 4. Simulation behavior: boot rom is initd
 * 5. Synthesis behavior : edit the simulation behavior to match the toolchain to init the boot rom
 * 6. Same cycle read&write behavior is undefined
 */

`timescale 1ns/1ps
`default_nettype none
import memory_pkg::*;

module sram_bank #(
    parameter int BANK_IDX = 0
) (
    input  logic                             i_clk,
    input  logic                             i_rst_n,
    input  logic                             i_req_valid,
    input  logic                             i_resp_expected,
    output logic                             o_req_ready,
    output logic                             o_resp_valid,
    input  logic                             i_resp_ready,
    input  logic [PORT_IDX_W-1:0]            i_req_port,
    input  logic [THRD_W-1:0]                i_req_thrd,
    input  logic                             i_lr,
    input  logic                             i_sc,
    input  logic [BANK_ADDR_W-1:0]           i_raddr,
    input  logic [BANK_ADDR_W-1:0]           i_waddr,
    input  logic [BANK_WORD_W/8-1:0]         i_wstrb,
    input  logic [XLEN-1:0]                  i_wdata,
    input  logic                             i_we,
    output logic                             o_sc_succ,
    output logic [PORT_IDX_W-1:0]            o_resp_port,
    output logic [THRD_W-1:0]                o_resp_thrd,
    output logic [XLEN-1:0]                  o_rdata
);
    logic [XLEN-1:0]          mem  [BANK_DEPTH-1:0] /* verilator public_flat_rw */;
    logic                     r_resv_valid;
    logic [BANK_ADDR_W-1:0]   r_resv_addr;
    logic [THRD_W-1:0]        r_resv_thrd;
    logic [BANK_WORD_W/8-1:0] r_resv_wstrb;
    logic                     w_sc_succ;

    assign o_req_ready = !o_resp_valid || i_resp_ready;
    assign w_sc_succ   = r_resv_valid && (r_resv_addr == i_waddr) &&
                         (r_resv_thrd == i_req_thrd) &&
                         (r_resv_wstrb == i_wstrb);
    assign o_sc_succ   = i_sc && w_sc_succ;
   
`ifndef SYNTHESIS
    string init_file;
    initial begin
        $sformat (init_file, "boot_rom/bank%0d.hex", BANK_IDX);
        $readmemh(init_file, mem);
    end
`endif

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_resv_valid  <= 1'b0;
            r_resv_addr   <= '0;
            r_resv_thrd   <= '0;
            r_resv_wstrb  <= '0;
            o_rdata      <= {XLEN{1'b0}};
            o_resp_valid <= 1'b0;
            o_resp_port  <= '0;
            o_resp_thrd  <= '0;
        end else begin
            if (o_req_ready) begin
                o_resp_valid <= i_req_valid && i_resp_expected;
                o_resp_port  <= i_req_port;
                o_resp_thrd  <= i_req_thrd;
            end
            if (i_req_valid && o_req_ready && i_we && (!i_sc || w_sc_succ)) begin
                for (int i = 0; i < BANK_WORD_W/8; i++) begin
                    if (i_wstrb[i]) begin
                        mem[i_waddr][i*8 +: 8] <= i_wdata[i*8 +: 8];
                    end
                end
                if (r_resv_valid && r_resv_addr == i_waddr) begin
                    r_resv_valid <= 1'b0;
                end
            end
            if (i_req_valid && o_req_ready && i_lr) begin
                r_resv_valid <= 1'b1;
                r_resv_addr  <= i_raddr;
                r_resv_thrd  <= i_req_thrd;
                r_resv_wstrb <= i_wstrb;
            end
            if (i_req_valid && o_req_ready && i_sc && r_resv_valid &&
                r_resv_thrd == i_req_thrd) begin
                /* Every SC attempt invalidates that hart's reservation. */
                r_resv_valid <= 1'b0;
            end
            if (i_req_valid && o_req_ready) begin
                o_rdata <= mem[i_raddr];
            end
        end
    end
endmodule: sram_bank
