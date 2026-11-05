`default_nettype none
import memory_pkg::*;
module memory_formal (
    input logic clk, input logic rst_n,
    input logic req_we, input logic [THRD_W-1:0] req_thrd,
    input logic req_is_lr, input logic req_is_sc,
    input logic [VIR_ADDR_W-1:0] req_addr, input logic [XLEN/8-1:0] req_wstrb,
    input logic [XLEN-1:0] req_wdata, input logic req_valid,
    input logic [1:0] req_priv, input logic resp_ready,
    input logic page_msg_valid, input logic [PAGE_MSG_W-1:0] page_msg,
    input logic page_msg_ready, input logic page_req_ready,
    input logic [VIR_ADDR_W-1:0] page_resp_addr, input logic page_resp_we,
    input logic [LINE_W-1:0] page_resp_wdata, input logic page_resp_valid,
    input logic page_transfer_done
);
    logic req_we_a[0:0]; logic [THRD_W-1:0] req_thrd_a[0:0];
    logic req_is_lr_a[0:0], req_is_sc_a[0:0]; logic [VIR_ADDR_W-1:0] req_addr_a[0:0];
    logic [XLEN/8-1:0] req_wstrb_a[0:0]; logic [XLEN-1:0] req_wdata_a[0:0];
    logic req_valid_a[0:0]; logic [1:0] req_priv_a[0:0]; logic req_ready_a[0:0];
    logic [THRD_W-1:0] resp_thrd_a[0:0]; logic resp_sc_a[0:0];
    logic [XLEN-1:0] resp_rdata_a[0:0]; logic resp_valid_a[0:0], resp_ready_a[0:0];
    logic page_msg_valid_a[0:0], page_msg_in_ready_a[0:0];
    logic [PAGE_MSG_W-1:0] page_msg_a[0:0]; logic page_msg_out_ready_a[0:0];
    logic page_msg_out_valid_a[0:0]; logic [PAGE_MSG_W-1:0] page_msg_out_a[0:0];
    logic page_req_we, page_req_valid; logic [VIR_ADDR_W-1:0] page_req_addr;
    logic [LINE_W-1:0] page_req_wdata; logic page_resp_ready;
    logic page_completion_pending; logic [THRD_W-1:0] page_completion_thrd;
    logic f_past_valid = 1'b0;

    always_comb begin
        req_we_a[0]=req_we; req_thrd_a[0]=req_thrd; req_is_lr_a[0]=req_is_lr;
        req_is_sc_a[0]=req_is_sc; req_addr_a[0]=req_addr; req_wstrb_a[0]=req_wstrb;
        req_wdata_a[0]=req_wdata; req_valid_a[0]=req_valid; req_priv_a[0]=req_priv;
        resp_ready_a[0]=resp_ready; page_msg_valid_a[0]=page_msg_valid;
        page_msg_a[0]=page_msg; page_msg_out_ready_a[0]=page_msg_ready;
    end
    memory dut (
        .i_clk(clk),.i_rst_n(rst_n),.i_req_we(req_we_a),.i_req_thrd(req_thrd_a),
        .i_req_is_lr(req_is_lr_a),.i_req_is_sc(req_is_sc_a),.i_req_addr(req_addr_a),
        .i_req_wstrb(req_wstrb_a),.i_req_wdata(req_wdata_a),.i_req_valid(req_valid_a),
        .i_req_priv(req_priv_a),.o_req_ready(req_ready_a),.o_resp_thrd(resp_thrd_a),
        .o_resp_sc_succ(resp_sc_a),.o_resp_rdata(resp_rdata_a),.o_resp_valid(resp_valid_a),
        .i_resp_ready(resp_ready_a),.i_page_msg_valid(page_msg_valid_a),
        .o_page_msg_ready(page_msg_in_ready_a),.i_page_msg(page_msg_a),
        .i_page_msg_ready(page_msg_out_ready_a),.o_page_msg_valid(page_msg_out_valid_a),
        .o_page_msg(page_msg_out_a),.o_page_req_we(page_req_we),
        .o_page_req_valid(page_req_valid),.i_page_req_ready(page_req_ready),
        .o_page_req_addr(page_req_addr),.o_page_req_wdata(page_req_wdata),
        .i_page_resp_addr(page_resp_addr),.i_page_resp_we(page_resp_we),
        .i_page_resp_wdata(page_resp_wdata),.i_page_resp_valid(page_resp_valid),
        .o_page_resp_ready(page_resp_ready),.i_page_transfer_done(page_transfer_done),
        .o_page_completion_pending(page_completion_pending),
        .o_page_completion_thrd(page_completion_thrd)
    );
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    `include "memory_assumptions.sv"
    `include "memory_reset.sv"
    `include "memory_protocol.sv"
    `include "memory_coverpoints.sv"
endmodule: memory_formal
`default_nettype wire

