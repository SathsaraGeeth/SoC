/* SPDX-License-Identifier: Apache-2.0 */

interface router_if;
    logic clk;
    logic rst_n;

    logic                            req_instr_valid;
    logic                            req_instr_ready;
    logic [topology_pkg::VIR_ADDR_W-1:0] req_instr_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] req_instr_thrd_id;
    logic [1:0]                      req_instr_priv;
    logic                            resp_instr_valid;
    logic                            resp_instr_ready;
    logic [core_pkg::XLEN-1:0]       resp_instr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] resp_instr_thrd_id;

    logic                            req_data_valid;
    logic                            req_data_ready;
    logic [topology_pkg::VIR_ADDR_W-1:0] req_data_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] req_data_thrd_id;
    logic [1:0]                      req_data_priv;
    logic                            req_data_rw;
    logic                            req_data_lq;
    logic                            req_data_sc;
    logic [core_pkg::XLEN/8-1:0]     req_data_wstrb;
    logic [core_pkg::XLEN-1:0]       req_data_wdata;
    logic                            resp_data_valid;
    logic                            resp_data_ready;
    logic [core_pkg::XLEN-1:0]       resp_data_rdata;
    logic                            resp_data_sc_ok;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] resp_data_thrd_id;

    logic                            mmio_req_valid;
    logic                            mmio_req_ready;
    logic [topology_pkg::VIR_ADDR_W-1:0] mmio_req_addr;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mmio_req_thrd_id;
    logic [1:0]                      mmio_req_priv;
    logic                            mmio_req_rw;
    logic [core_pkg::XLEN/8-1:0]     mmio_req_wstrb;
    logic [core_pkg::XLEN-1:0]       mmio_req_wdata;
    logic                            mmio_resp_valid;
    logic                            mmio_resp_ready;
    logic [core_pkg::XLEN-1:0]       mmio_resp_rdata;
    logic                            mmio_resp_sc_ok;
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mmio_resp_thrd_id;

    logic                            core_page_msg_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] core_page_msg;
    logic                            core_page_msg_ready;
    logic                            core_page_msg_instr_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] core_page_msg_instr;
    logic                            core_page_msg_instr_ready;
    logic                            core_page_msg_data_valid;
    logic [memory_pkg::PAGE_MSG_W-1:0] core_page_msg_data;
    logic                            core_page_msg_data_ready;

    logic                            mem_page_msg_valid       [3:0];
    logic [memory_pkg::PAGE_MSG_W-1:0] mem_page_msg           [3:0];
    logic                            mem_page_msg_ready       [3:0];
    logic                            mem_page_msg_instr_valid [3:0];
    logic [memory_pkg::PAGE_MSG_W-1:0] mem_page_msg_instr     [3:0];
    logic                            mem_page_msg_instr_ready [3:0];
    logic                            mem_page_msg_data_valid  [3:0];
    logic [memory_pkg::PAGE_MSG_W-1:0] mem_page_msg_data      [3:0];
    logic                            mem_page_msg_data_ready  [3:0];

    logic                            mem_req_instr_valid      [3:0];
    logic                            mem_req_instr_ready      [3:0];
    logic [topology_pkg::VIR_ADDR_W-1:0] mem_req_instr_addr  [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mem_req_instr_thrd_id [3:0];
    logic [1:0]                      mem_req_instr_priv       [3:0];
    logic                            mem_resp_instr_valid     [3:0];
    logic                            mem_resp_instr_ready     [3:0];
    logic [core_pkg::XLEN-1:0]       mem_resp_instr_rdata     [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mem_resp_instr_thrd_id [3:0];

    logic                            mem_req_data_valid       [3:0];
    logic                            mem_req_data_ready       [3:0];
    logic [topology_pkg::VIR_ADDR_W-1:0] mem_req_data_addr   [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mem_req_data_thrd_id [3:0];
    logic [1:0]                      mem_req_data_priv        [3:0];
    logic                            mem_req_data_rw          [3:0];
    logic                            mem_req_data_lq          [3:0];
    logic                            mem_req_data_sc          [3:0];
    logic [core_pkg::XLEN/8-1:0]     mem_req_data_wstrb       [3:0];
    logic [core_pkg::XLEN-1:0]       mem_req_data_wdata       [3:0];
    logic                            mem_resp_data_valid      [3:0];
    logic                            mem_resp_data_ready      [3:0];
    logic [core_pkg::XLEN-1:0]       mem_resp_data_rdata      [3:0];
    logic                            mem_resp_data_sc_ok      [3:0];
    logic [$clog2(core_pkg::NUM_HW_THRDS)-1:0] mem_resp_data_thrd_id [3:0];
endinterface: router_if
