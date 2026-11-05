/*
 * lsu.sv
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
 * 1. Performace goals:
 *    i. module should be able to accept a new request every cycle
 */

`default_nettype none
import lsu_pkg::*;
import isa_pkg::*;
import frontend_pkg::*;

module lsu (
    input  logic                            i_clk,
    input  logic                            i_rst_n,

    input  epoch_t                          i_valid_epoch   [NUM_HW_THRD-1:0],

    input  logic                            i_req_data_ready,
    output logic                            o_req_data_valid,
    output mem_req_t                        o_req_data,
    output logic                            o_resp_data_ready,
    input  logic                            i_resp_data_valid,
    input  mem_resp_t                       i_resp_data,
    input  logic                            i_resp_page_msg_data_valid,
    output logic                            o_resp_page_msg_data_ready,
    input  mem_page_resp_t                  i_resp_page_msg_data,

    input  logic                            i_lsu_req_valid,
    output logic                            o_lsu_req_ready,
    input  logic [PRIV_MODE_W-1:0]          i_lsu_req_priv_mode,
    input  logic [VIR_ADDR_W-1:0]           i_lsu_req_addr,
    input  logic [XLEN-1:0]                 i_lsu_req_data,
    input  lsu_op_e                         i_lsu_req_op,

    output logic                            o_lsu_resp_valid,
    input  logic                            i_lsu_resp_ready,
    output logic                            o_lsu_resp_page_fault,
    
    output logic [XLEN-1:0]                 o_lsu_resp_data
);
    logic                           w_req_buff_clk;
    logic                           w_req_buff_rst_n;
    logic                           w_req_buff_enq_valid;
    logic                           w_req_buff_enq_ready;
    mem_req_t                       w_req_buff_enq_data;

    circular_buffer #(
        .DEPTH                      (FU_Q_DEPTH),
        .WIDTH                      ($bits(mem_req_t))
    ) fu_fifo (
        .i_clk                      (i_clk),
        .i_rst_n                    (i_rst_n),
        .o_head_data                (w_fu_fifo_head_data[i]),
        .o_deq_ready                (w_fu_fifo_deq_ready[i]),
        .i_deq_valid                (w_fu_fifo_deq_valid[i]),
        .i_enq_tail_data            (w_fu_fifo_enq_data[i]),
        .i_enq_valid                (w_fu_fifo_enq_valid[i]),
        .o_enq_ready                (w_fu_fifo_enq_ready[i]),
        .o_full                     (),
        .o_empty                    (),
        .o_level                    (w_fu_fifo_level[i]),
        .i_clr_n                    (1'b1)
    );

endmodule: lsu

`default_nettype wire
