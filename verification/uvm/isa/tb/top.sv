`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;
`include "random_test.sv"

module tb_top;
    localparam time CLK_HALF = 5ns;
    logic clk = 1'b0, rst_n = 1'b0;
    logic [core_pkg::XLEN-1:0] thrd_ids [NUM_HW_THRDS-1:0];
    logic req_instr_ready, req_instr_valid, resp_instr_ready, resp_instr_valid;
    logic [VIR_ADDR_W-1:0] req_instr_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0] req_instr_thrd_id, resp_instr_thrd_id;
    logic [PRIV_MODE_W-1:0] req_instr_priv;
    logic [core_pkg::XLEN-1:0] resp_instr;
    logic req_data_ready, req_data_valid, resp_data_ready, resp_data_valid;
    logic [VIR_ADDR_W-1:0] req_data_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0] req_data_thrd_id, resp_data_thrd_id;
    logic [PRIV_MODE_W-1:0] req_data_priv;
    logic req_data_rw, req_data_lq, req_data_sc, resp_data_sc_ok;
    logic [core_pkg::XLEN/8-1:0] req_data_wstrb;
    logic [core_pkg::XLEN-1:0] req_data_wdata, resp_data_rdata;

    always #CLK_HALF clk = ~clk;
    initial #100ns rst_n = 1'b1;
    for (genvar t = 0; t < NUM_HW_THRDS; t++)
        assign thrd_ids[t] = core_pkg::XLEN'(t);

    core dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_thrd_id_vec(thrd_ids),
        .i_wake_intr_vec('0), .i_irq_timer_vec('0),
        .i_req_instr_ready(req_instr_ready), .o_req_instr_addr(req_instr_addr),
        .o_req_instr_thrd_id(req_instr_thrd_id), .o_req_instr_priv(req_instr_priv),
        .o_req_instr_valid(req_instr_valid), .o_resp_instr_ready(resp_instr_ready),
        .i_resp_instr(resp_instr), .i_resp_instr_thrd_id(resp_instr_thrd_id),
        .i_resp_instr_valid(resp_instr_valid),
        .i_req_data_ready(req_data_ready), .o_req_data_addr(req_data_addr),
        .o_req_data_thrd_id(req_data_thrd_id), .o_req_data_priv(req_data_priv),
        .o_req_data_rw(req_data_rw), .o_req_data_lq(req_data_lq),
        .o_req_data_sc(req_data_sc), .o_req_data_wstrb(req_data_wstrb),
        .o_req_data_wdata(req_data_wdata), .o_req_data_valid(req_data_valid),
        .o_resp_data_ready(resp_data_ready), .i_resp_data_rdata(resp_data_rdata),
        .i_resp_data_sc_ok(resp_data_sc_ok), .i_resp_data_thrd_id(resp_data_thrd_id),
        .i_resp_data_valid(resp_data_valid),
        .i_page_msg_instr_valid(1'b0), .i_page_msg_instr('0),
        .o_page_msg_instr_ready(), .i_page_msg_data_valid(1'b0),
        .i_page_msg_data('0), .o_page_msg_data_ready(),
        .o_page_msg_valid(), .o_page_msg(), .i_page_msg_ready(1'b1)
    );

    test_memory memory (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_req_instr_addr(req_instr_addr), .i_req_instr_thrd_id(req_instr_thrd_id),
        .i_req_instr_valid(req_instr_valid), .o_req_instr_ready(req_instr_ready),
        .o_resp_instr(resp_instr), .o_resp_instr_thrd_id(resp_instr_thrd_id),
        .o_resp_instr_valid(resp_instr_valid), .i_resp_instr_ready(resp_instr_ready),
        .i_req_data_addr(req_data_addr), .i_req_data_thrd_id(req_data_thrd_id),
        .i_req_data_rw(req_data_rw), .i_req_data_lr(req_data_lq),
        .i_req_data_sc(req_data_sc),
        .i_req_data_wstrb(req_data_wstrb), .i_req_data_wdata(req_data_wdata),
        .i_req_data_valid(req_data_valid), .o_req_data_ready(req_data_ready),
        .o_resp_data_rdata(resp_data_rdata), .o_resp_data_sc_ok(resp_data_sc_ok),
        .o_resp_data_thrd_id(resp_data_thrd_id), .o_resp_data_valid(resp_data_valid),
        .i_resp_data_ready(resp_data_ready)
    );

    initial begin
        uvm_config_db#(virtual commit_if)::set(
            null, "*", "vif", dut.u_commit_binder.iface);
        run_test("random_test");
    end
endmodule
