`default_nettype none

module router_formal (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_req_instr_valid,
    input logic [topology_pkg::VIR_ADDR_W-1:0] i_req_instr_addr,
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_req_instr_thrd_id,
    input logic [1:0] i_req_instr_priv,
    input logic i_resp_instr_ready,
    input logic i_req_data_valid,
    input logic [topology_pkg::VIR_ADDR_W-1:0] i_req_data_addr,
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_req_data_thrd_id,
    input logic [1:0] i_req_data_priv,
    input logic i_req_data_rw,
    input logic i_req_data_lq,
    input logic i_req_data_sc,
    input logic [core_pkg::XLEN/8-1:0] i_req_data_wstrb,
    input logic [core_pkg::XLEN-1:0] i_req_data_wdata,
    input logic i_resp_data_ready,
    input logic i_mmio_req_ready,
    input logic i_mmio_resp_valid,
    input logic [core_pkg::XLEN-1:0] i_mmio_resp_rdata,
    input logic i_mmio_resp_sc_ok,
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_mmio_resp_thrd_id,
    input logic i_core_page_msg_valid,
    input logic [memory_pkg::PAGE_MSG_W-1:0] i_core_page_msg,
    input logic i_core_page_msg_instr_ready,
    input logic i_core_page_msg_data_ready,
    input logic i_mem_page_msg_ready [3:0],
    input logic i_mem_page_msg_instr_valid [3:0],
    input logic [memory_pkg::PAGE_MSG_W-1:0] i_mem_page_msg_instr [3:0],
    input logic i_mem_page_msg_data_valid [3:0],
    input logic [memory_pkg::PAGE_MSG_W-1:0] i_mem_page_msg_data [3:0],
    input logic i_mem_req_instr_ready [3:0],
    input logic i_mem_resp_instr_valid [3:0],
    input logic [core_pkg::XLEN-1:0] i_mem_resp_instr_rdata [3:0],
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_mem_resp_instr_thrd_id [3:0],
    input logic i_mem_req_data_ready [3:0],
    input logic i_mem_resp_data_valid [3:0],
    input logic [core_pkg::XLEN-1:0] i_mem_resp_data_rdata [3:0],
    input logic i_mem_resp_data_sc_ok [3:0],
    input logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] i_mem_resp_data_thrd_id [3:0]
);
    logic o_req_instr_ready;
    logic o_resp_instr_valid;
    logic [core_pkg::XLEN-1:0] o_resp_instr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_resp_instr_thrd_id;
    logic o_req_data_ready;
    logic o_resp_data_valid;
    logic [core_pkg::XLEN-1:0] o_resp_data_rdata;
    logic o_resp_data_sc_ok;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_resp_data_thrd_id;
    logic o_mmio_req_valid;
    logic [topology_pkg::VIR_ADDR_W-1:0] o_mmio_req_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_mmio_req_thrd_id;
    logic [1:0] o_mmio_req_priv;
    logic o_mmio_req_rw;
    logic [core_pkg::XLEN/8-1:0] o_mmio_req_wstrb;
    logic [core_pkg::XLEN-1:0] o_mmio_req_wdata;
    logic o_mmio_resp_ready;
    logic o_core_page_msg_ready;
    logic o_core_page_msg_instr_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] o_core_page_msg_instr;
    logic o_core_page_msg_data_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] o_core_page_msg_data;
    logic o_mem_page_msg_valid [3:0];
    logic [memory_pkg::PAGE_MSG_W-1:0] o_mem_page_msg [3:0];
    logic o_mem_page_msg_instr_ready [3:0];
    logic o_mem_page_msg_data_ready [3:0];
    logic o_mem_req_instr_valid [3:0];
    logic [topology_pkg::VIR_ADDR_W-1:0] o_mem_req_instr_addr [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_mem_req_instr_thrd_id [3:0];
    logic [1:0] o_mem_req_instr_priv [3:0];
    logic o_mem_resp_instr_ready [3:0];
    logic o_mem_req_data_valid [3:0];
    logic [topology_pkg::VIR_ADDR_W-1:0] o_mem_req_data_addr [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] o_mem_req_data_thrd_id [3:0];
    logic [1:0] o_mem_req_data_priv [3:0];
    logic o_mem_req_data_rw [3:0];
    logic o_mem_req_data_lq [3:0];
    logic o_mem_req_data_sc [3:0];
    logic [core_pkg::XLEN/8-1:0] o_mem_req_data_wstrb [3:0];
    logic [core_pkg::XLEN-1:0] o_mem_req_data_wdata [3:0];
    logic o_mem_resp_data_ready [3:0];
    logic f_past_valid = 1'b0;

    router #(
        .C_X (0),
        .C_Y (0)
    ) dut (.*);

    always_ff @(posedge i_clk)
        f_past_valid <= 1'b1;

    `include "router_assumptions.sv"
    `include "router_reset.sv"
    `include "router_requests.sv"
    `include "router_page_messages.sv"
    `include "router_responses.sv"
    `include "router_coverpoints.sv"
endmodule: router_formal

`default_nettype wire
