`default_nettype none

import core_pkg::*;

module alu_formal (
    input logic         clk,
    input logic         rst_n,
    input issue_instr_t issued_instr,
    input logic         req_valid,
    input logic         res_ready
);
    logic                            req_ready;
    logic [$clog2(NUM_HW_THRDS)-1:0] res_thrd_id;
    logic [XLEN-1:0]                 br_target;
    logic                            br_taken;
    logic                            res_valid;
    logic [VIR_ADDR_W-1:0]           result;
    logic                            f_past_valid = 1'b0;

    alu_lane #(
        .BRANCH_LANE (1'b1)
    ) dut (
        .i_clk          (clk),
        .i_rst_n        (rst_n),
        .i_issued_instr (issued_instr),
        .o_req_ready    (req_ready),
        .i_req_valid    (req_valid),
        .o_res_thrd_id  (res_thrd_id),
        .o_br_target    (br_target),
        .o_br_taken     (br_taken),
        .o_res_valid    (res_valid),
        .i_res_ready    (res_ready),
        .o_result       (result)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "alu_assumptions.sv"
    `include "alu_reset.sv"
    `include "alu_handshake.sv"
    `include "alu_result.sv"
    `include "alu_coverpoints.sv"
endmodule: alu_formal

`default_nettype wire

