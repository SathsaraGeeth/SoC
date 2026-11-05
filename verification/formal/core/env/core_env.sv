`default_nettype none

module core_formal (
    input logic i_clk,
    input logic i_rst_n,
    input logic [core_pkg::XLEN-1:0] i_thrd_id_vec [core_pkg::NUM_HW_THRDS-1:0],
    input logic [core_pkg::NUM_HW_THRDS-1:0] i_wake_intr_vec,
    input logic [core_pkg::NUM_HW_THRDS-1:0] i_irq_timer_vec,
    input logic i_req_instr_ready,
    input logic [core_pkg::XLEN-1:0] i_resp_instr,
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_resp_instr_thrd_id,
    input logic i_resp_instr_valid,
    input logic i_page_msg_instr_valid,
    input logic [memory_pkg::PAGE_MSG_W-1:0] i_page_msg_instr,
    input logic i_req_data_ready,
    input logic [core_pkg::XLEN-1:0] i_resp_data_rdata,
    input logic i_resp_data_sc_ok,
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_resp_data_thrd_id,
    input logic i_resp_data_valid,
    input logic i_page_msg_data_valid,
    input logic [memory_pkg::PAGE_MSG_W-1:0] i_page_msg_data,
    input logic i_page_msg_ready
);
    logic [core_pkg::VIR_ADDR_W-1:0] o_req_instr_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_req_instr_thrd_id;
    logic [isa_pkg::PRIV_MODE_W-1:0] o_req_instr_priv;
    logic o_req_instr_valid;
    logic o_resp_instr_ready;
    logic o_page_msg_instr_ready;
    logic [core_pkg::VIR_ADDR_W-1:0] o_req_data_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_req_data_thrd_id;
    logic [isa_pkg::PRIV_MODE_W-1:0] o_req_data_priv;
    logic o_req_data_rw;
    logic o_req_data_lq;
    logic o_req_data_sc;
    logic [core_pkg::XLEN/8-1:0] o_req_data_wstrb;
    logic [core_pkg::XLEN-1:0] o_req_data_wdata;
    logic o_req_data_valid;
    logic o_resp_data_ready;
    logic o_page_msg_data_ready;
    logic o_page_msg_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] o_page_msg;
    logic f_past_valid = 1'b0;

    core #(
        .RESET_VEC ('0)
    ) dut (.*);

    always_ff @(posedge i_clk)
        f_past_valid <= 1'b1;

    `include "core_assumptions.sv"
    `include "core_reset.sv"
    `include "core_instruction_protocol.sv"
    `include "core_data_protocol.sv"
    `include "core_page_protocol.sv"
    `include "core_coverpoints.sv"
endmodule: core_formal

`default_nettype wire
