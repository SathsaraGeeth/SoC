`default_nettype none

import core_pkg::*;

module regfile_formal (
    input logic                            clk,
    input logic                            we,
    input logic [$clog2(REG_COUNT)-1:0]    rs1_addr,
    input logic [$clog2(REG_COUNT)-1:0]    rs2_addr,
    input logic [$clog2(REG_COUNT)-1:0]    rs3_addr,
    input logic [$clog2(NUM_HW_THRDS)-1:0] rthrd_id,
    input logic [$clog2(REG_COUNT)-1:0]    rd_addr,
    input logic [$clog2(NUM_HW_THRDS)-1:0] wthrd_id,
    input logic [XLEN-1:0]                 rd_wdata
);
    logic [XLEN-1:0] rs1_data;
    logic [XLEN-1:0] rs2_data;
    logic [XLEN-1:0] rs3_data;
    logic            f_past_valid = 1'b0;

    regfile dut (
        .i_clk(clk),
        .i_we(we),
        .i_rs1_addr(rs1_addr),
        .i_rs2_addr(rs2_addr),
        .i_rs3_addr(rs3_addr),
        .i_rthrd_id(rthrd_id),
        .i_rd_addr(rd_addr),
        .i_wthrd_id(wthrd_id),
        .i_rd_wdata(rd_wdata),
        .o_rs1_data(rs1_data),
        .o_rs2_data(rs2_data),
        .o_rs3_data(rs3_data)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "regfile_x0.sv"
    `include "regfile_reads.sv"
    `include "regfile_coverpoints.sv"
endmodule

`default_nettype wire
