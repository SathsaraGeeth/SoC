`timescale 1ns/1ps
`default_nettype none

import core_pkg::*;
import memory_pkg::*;
import topology_pkg::*;
import isa_pkg::*;
import sys_cnfg_pkg::*;
import soc_pkg::*;

module soc (
    input  logic                                        i_clk,
    input  logic                                        i_rst_n,
    input  logic                                        i_uart_rx,
    output logic                                        o_uart_tx,
    output logic [63:0]                                 m_axi4_page_awaddr,
    output logic [7:0]                                  m_axi4_page_awlen,
    output logic [2:0]                                  m_axi4_page_awsize,
    output logic [1:0]                                  m_axi4_page_awburst,
    output logic                                        m_axi4_page_awlock,
    output logic [3:0]                                  m_axi4_page_awcache,
    output logic [2:0]                                  m_axi4_page_awprot,
    output logic [3:0]                                  m_axi4_page_awqos,
    output logic [3:0]                                  m_axi4_page_awregion,
    output logic [5:0]                                  m_axi4_page_awid,
    output logic                                        m_axi4_page_awvalid,
    input  logic                                        m_axi4_page_awready,
    output logic [63:0]                                 m_axi4_page_wdata,
    output logic [7:0]                                  m_axi4_page_wstrb,
    output logic                                        m_axi4_page_wlast,
    output logic                                        m_axi4_page_wvalid,
    input  logic                                        m_axi4_page_wready,
    input  logic [1:0]                                  m_axi4_page_bresp,
    input  logic [5:0]                                  m_axi4_page_bid,
    input  logic                                        m_axi4_page_bvalid,
    output logic                                        m_axi4_page_bready,
    output logic [63:0]                                 m_axi4_page_araddr,
    output logic [7:0]                                  m_axi4_page_arlen,
    output logic [2:0]                                  m_axi4_page_arsize,
    output logic [1:0]                                  m_axi4_page_arburst,
    output logic                                        m_axi4_page_arlock,
    output logic [3:0]                                  m_axi4_page_arcache,
    output logic [2:0]                                  m_axi4_page_arprot,
    output logic [3:0]                                  m_axi4_page_arqos,
    output logic [3:0]                                  m_axi4_page_arregion,
    output logic [5:0]                                  m_axi4_page_arid,
    output logic                                        m_axi4_page_arvalid,
    input  logic                                        m_axi4_page_arready,
    input  logic [63:0]                                 m_axi4_page_rdata,
    input  logic [1:0]                                  m_axi4_page_rresp,
    input  logic                                        m_axi4_page_rlast,
    input  logic [5:0]                                  m_axi4_page_rid,
    input  logic                                        m_axi4_page_rvalid,
    output logic                                        m_axi4_page_rready
);
    /*--- */
    // i_rst_n is asynchronous at the SoC boundary.  Keep assertion
    // asynchronous, but release each independently resettable block only
    // after it has been synchronized to its receiving clock.
    logic                                               rst_fabric_n;
    logic                                               rst_cluster_n [NUM_CLUSTER-1:0];
    logic                                               rst_mem_n     [NUM_MEM-1:0];
    logic                                               rst_periph_n;
    logic                                               rst_accel_n;
    logic                                               w_core_clk                                      [NUM_CORES-1:0];
    logic                                               w_core_rst_n                                    [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_core_thrd_id_vec                              [NUM_CORES-1:0] [NUM_HW_THRDS-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_wake_intr_vec                            [NUM_CORES-1:0];
    logic                                               w_core_req_instr_ready                          [NUM_CORES-1:0];
    logic [VIR_ADDR_W-1:0]                              w_core_req_instr_addr                           [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    w_core_req_instr_thrd_id                        [NUM_CORES-1:0];
    logic [1:0]                                         w_core_req_instr_priv                           [NUM_CORES-1:0];
    logic                                               w_core_req_instr_valid                          [NUM_CORES-1:0];
    logic                                               w_core_resp_instr_ready                         [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_core_resp_instr                               [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    w_core_resp_instr_thrd_id                       [NUM_CORES-1:0];
    logic                                               w_core_resp_instr_valid                         [NUM_CORES-1:0];
    logic                                               w_core_req_data_ready                           [NUM_CORES-1:0];
    logic [VIR_ADDR_W-1:0]                              w_core_req_data_addr                            [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    w_core_req_data_thrd_id                         [NUM_CORES-1:0];
    logic [1:0]                                         w_core_req_data_priv                            [NUM_CORES-1:0];
    logic                                               w_core_req_data_rw                              [NUM_CORES-1:0];
    logic                                               w_core_req_data_lq                              [NUM_CORES-1:0];
    logic                                               w_core_req_data_sc                              [NUM_CORES-1:0];
    logic [XLEN/8-1:0]                                  w_core_req_data_wstrb                           [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_core_req_data_wdata                           [NUM_CORES-1:0];
    logic                                               w_core_req_data_valid                           [NUM_CORES-1:0];
    logic                                               w_core_resp_data_ready                          [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_core_resp_data_rdata                          [NUM_CORES-1:0];
    logic                                               w_core_resp_data_sc_ok                          [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    w_core_resp_data_thrd_id                        [NUM_CORES-1:0];
    logic                                               w_core_resp_data_valid                          [NUM_CORES-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_irq_timer_vec                            [NUM_CORES-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_timer_req_valid                          [NUM_CORES-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_timer_resp_valid                         [NUM_CORES-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_timer_req_ready                          [NUM_CORES-1:0];
    logic [NUM_HW_THRDS-1:0]                            w_core_timer_resp_ready                         [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_core_timer_resp_rdata                         [NUM_CORES-1:0] [NUM_HW_THRDS-1:0];
    logic [PAGE_MSG_W-1:0]                              w_core_page_msg_instr                         [NUM_CORES-1:0];
    logic                                               w_core_page_msg_instr_valid                   [NUM_CORES-1:0];
    logic                                               w_core_page_msg_instr_ready                     [NUM_CORES-1:0];
    logic                                               w_core_page_msg_data_ready                      [NUM_CORES-1:0];
    logic [PAGE_MSG_W-1:0]                              w_core_page_msg_data                          [NUM_CORES-1:0];
    logic                                               w_core_page_msg_data_valid                    [NUM_CORES-1:0];
    logic [PAGE_MSG_W-1:0]                              w_core_page_msg                                 [NUM_CORES-1:0];
    logic                                               w_core_page_msg_ready                           [NUM_CORES-1:0];
    logic                                               w_core_page_msg_valid                           [NUM_CORES-1:0]; 
    logic                                               w_router_mmio_req_valid                         [NUM_CORES-1:0];
    logic                                               w_router_mmio_req_ready                         [NUM_CORES-1:0];
    logic [VIR_ADDR_W-1:0]                              w_router_mmio_req_addr                          [NUM_CORES-1:0];
    logic [CORE_THRD_W-1:0]                             w_router_mmio_req_thrd_id                       [NUM_CORES-1:0];
    logic [1:0]                                         w_router_mmio_req_priv                          [NUM_CORES-1:0];
    logic                                               w_router_mmio_req_rw                            [NUM_CORES-1:0];
    logic [XLEN/8-1:0]                                  w_router_mmio_req_wstrb                         [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_router_mmio_req_wdata                         [NUM_CORES-1:0];
    logic                                               w_router_mmio_resp_valid                        [NUM_CORES-1:0];
    logic                                               w_router_mmio_resp_ready                        [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    w_router_mmio_resp_rdata                        [NUM_CORES-1:0];
    logic                                               w_router_mmio_resp_sc_ok                        [NUM_CORES-1:0];
    logic [CORE_THRD_W-1:0]                             w_router_mmio_resp_thrd_id                      [NUM_CORES-1:0];

    logic                                               w_memory_clk                                    [NUM_MEM-1:0];
    logic                                               w_memory_rst_n                                  [NUM_MEM-1:0];
    logic                                               w_memory_req_we                                 [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [THRD_W-1:0]                                  w_memory_req_thrd                               [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_req_is_lr                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_req_is_sc                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [VIR_ADDR_W-1:0]                              w_memory_req_addr                               [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [XLEN/8-1:0]                                  w_memory_req_wstrb                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [XLEN-1:0]                                    w_memory_req_wdata                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_req_valid                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [1:0]                                         w_memory_req_priv                               [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_req_ready                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [THRD_W-1:0]                                  w_memory_resp_thrd                              [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_resp_sc_succ                           [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [XLEN-1:0]                                    w_memory_resp_rdata                             [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_resp_valid                             [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_resp_ready                             [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_page_msg_valid                         [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_page_msg_ready                         [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [PAGE_MSG_W-1:0]                              w_memory_page_msg                               [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_o_page_msg_ready                       [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_o_page_msg_valid                       [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic [PAGE_MSG_W-1:0]                              w_memory_o_page_msg                             [NUM_MEM-1:0] [NUM_RW_PORTS-1:0];
    logic                                               w_memory_page_req_we                            [NUM_MEM-1:0];
    logic                                               w_memory_page_req_valid                         [NUM_MEM-1:0];
    logic                                               w_memory_page_req_ready                         [NUM_MEM-1:0];
    logic [VIR_ADDR_W-1:0]                              w_memory_page_req_addr                          [NUM_MEM-1:0];
    logic [NUM_BANKS*XLEN-1:0]                          w_memory_page_req_wdata                         [NUM_MEM-1:0];
    logic [VIR_ADDR_W-1:0]                              w_memory_page_resp_addr                         [NUM_MEM-1:0];
    logic                                               w_memory_page_resp_we                           [NUM_MEM-1:0];
    logic [NUM_BANKS*XLEN-1:0]                          w_memory_page_resp_wdata                        [NUM_MEM-1:0];
    logic                                               w_memory_page_resp_valid                        [NUM_MEM-1:0];
    logic                                               w_memory_page_resp_ready                        [NUM_MEM-1:0];
    logic                                               w_memory_page_transfer_done                     [NUM_MEM-1:0];
    logic                                               w_memory_page_completion_pending                [NUM_MEM-1:0];
    logic [THRD_W-1:0]                                  w_memory_page_completion_thrd                   [NUM_MEM-1:0];

    /* Page engine wires */
    logic                                               w_page_clk;
    logic                                               w_page_rst_n;
    logic                                               w_page_req_we;
    logic                                               w_page_req_valid;
    logic [VIR_ADDR_W-1:0]                              w_page_req_addr;
    logic [NUM_BANKS*XLEN-1:0]                          w_page_req_wdata;
    logic                                               w_page_req_ready;
    logic                                               w_page_resp_ready;
    logic                                               w_page_resp_valid;
    logic [VIR_ADDR_W-1:0]                              w_page_resp_addr;
    logic                                               w_page_resp_we;
    logic [NUM_BANKS*XLEN-1:0]                          w_page_resp_wdata;
    logic                                               w_page_transfer_done;
    logic [63:0]                                        w_page_m_axi4_page_awaddr;
    logic [7:0]                                         w_page_m_axi4_page_awlen;
    logic [2:0]                                         w_page_m_axi4_page_awsize;
    logic [1:0]                                         w_page_m_axi4_page_awburst;
    logic                                               w_page_m_axi4_page_awlock;
    logic [3:0]                                         w_page_m_axi4_page_awcache;
    logic [2:0]                                         w_page_m_axi4_page_awprot;
    logic [3:0]                                         w_page_m_axi4_page_awqos;
    logic [3:0]                                         w_page_m_axi4_page_awregion;
    logic [5:0]                                         w_page_m_axi4_page_awid;
    logic                                               w_page_m_axi4_page_awvalid;
    logic                                               w_page_m_axi4_page_awready;
    logic [63:0]                                        w_page_m_axi4_page_wdata;
    logic [7:0]                                         w_page_m_axi4_page_wstrb;
    logic                                               w_page_m_axi4_page_wlast;
    logic                                               w_page_m_axi4_page_wvalid;
    logic                                               w_page_m_axi4_page_wready;
    logic [1:0]                                         w_page_m_axi4_page_bresp;
    logic [5:0]                                         w_page_m_axi4_page_bid;
    logic                                               w_page_m_axi4_page_bvalid;
    logic                                               w_page_m_axi4_page_bready;
    logic [63:0]                                        w_page_m_axi4_page_araddr;
    logic [7:0]                                         w_page_m_axi4_page_arlen;
    logic [2:0]                                         w_page_m_axi4_page_arsize;
    logic [1:0]                                         w_page_m_axi4_page_arburst;
    logic                                               w_page_m_axi4_page_arlock;
    logic [3:0]                                         w_page_m_axi4_page_arcache;
    logic [2:0]                                         w_page_m_axi4_page_arprot;
    logic [3:0]                                         w_page_m_axi4_page_arqos;
    logic [3:0]                                         w_page_m_axi4_page_arregion;
    logic [5:0]                                         w_page_m_axi4_page_arid;
    logic                                               w_page_m_axi4_page_arvalid;
    logic                                               w_page_m_axi4_page_arready;
    logic [63:0]                                        w_page_m_axi4_page_rdata;
    logic [1:0]                                         w_page_m_axi4_page_rresp;
    logic                                               w_page_m_axi4_page_rlast;
    logic [5:0]                                         w_page_m_axi4_page_rid;
    logic                                               w_page_m_axi4_page_rvalid;
    logic                                               w_page_m_axi4_page_rready;

    logic                                               w_uart_mmio_clk;
    logic                                               w_uart_mmio_rst_n;
    logic                                               w_uart_mmio_req_valid;
    logic                                               w_uart_mmio_req_ready;
    logic                                               w_uart_mmio_req_we;
    logic [THRD_W-1:0]                                  w_uart_mmio_req_thrd;
    logic                                               w_uart_mmio_req_is_lr;
    logic                                               w_uart_mmio_req_is_sc;
    logic [1:0]                                         w_uart_mmio_req_priv;
    logic [VIR_ADDR_W-1:0]                              w_uart_mmio_req_addr;
    logic [XLEN-1:0]                                    w_uart_mmio_req_wdata;
    logic [XLEN/8-1:0]                                  w_uart_mmio_req_wstrb;
    logic                                               w_uart_mmio_resp_valid;
    logic [63:0]                                        w_uart_mmio_resp_rdata;
    logic [THRD_W-1:0]                                  w_uart_mmio_resp_thrd;
    logic                                               w_uart_mmio_resp_sc_succ;
    logic                                               w_uart_mmio_resp_ready;
    logic                                               w_uart_mmio_rx;
    logic                                               w_uart_mmio_tx;
    logic                                               w_sys_mmio_req_valid                         [NUM_CLUSTER-1:0];
    logic                                               w_sys_mmio_req_ready                         [NUM_CLUSTER-1:0];
    logic [VIR_ADDR_W-1:0]                              w_sys_mmio_req_addr                          [NUM_CLUSTER-1:0];
    logic [XLEN-1:0]                                    w_sys_mmio_req_wdata                         [NUM_CLUSTER-1:0];
    logic [XLEN/8-1:0]                                  w_sys_mmio_req_wmask                         [NUM_CLUSTER-1:0];
    logic                                               w_sys_mmio_resp_valid                        [NUM_CLUSTER-1:0];
    logic [XLEN-1:0]                                    w_sys_mmio_resp_rdata                        [NUM_CLUSTER-1:0];
    logic                                               w_sys_mmio_resp_ready                        [NUM_CLUSTER-1:0];
    logic                                               w_sys_intr                                   [NUM_CLUSTER-1:0];
    logic [XLEN-1:0]                                    w_sys_intr_thrd                              [NUM_CLUSTER-1:0];
    logic [NUM_CORES-1:0]                               w_sys_mmio_grant;
    logic                                               w_sys_req_we                                 [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [XLEN-1:0]                                    w_sys_req_thrd                               [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_req_is_lr                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_req_is_sc                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [VIR_ADDR_W-1:0]                              w_sys_req_addr                               [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [XLEN/8-1:0]                                  w_sys_req_wstrb                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [XLEN-1:0]                                    w_sys_req_wdata                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_req_valid                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_req_ready                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [XLEN-1:0]                                    w_sys_resp_thrd                              [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_resp_sc_succ                           [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [XLEN-1:0]                                    w_sys_resp_rdata                             [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_resp_valid                             [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic                                               w_sys_resp_ready                             [NUM_CLUSTER-1:0] [NUM_SYS_PORTS-1:0];
    logic [THREADS_PER_CLUSTER-1:0]                     r_ipi_vector                                  [NUM_CORES-1:0];
    logic                                               r_ipi_resp_valid                              [NUM_CORES-1:0];
    logic [XLEN-1:0]                                    r_ipi_resp_rdata                              [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    r_ipi_resp_thrd                               [NUM_CORES-1:0];
    logic [7:0]                                         r_ipi_wake_hold                               [NUM_CORES-1:0];
    logic                                               r_oob_resp_valid                              [NUM_CORES-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    r_oob_resp_thrd                               [NUM_CORES-1:0];
    logic [$clog2(CORES_PER_CLUSTER>1?CORES_PER_CLUSTER:2)-1:0] r_sys_resp_core                 [NUM_CLUSTER-1:0];
    logic [$clog2(NUM_HW_THRDS)-1:0]                    r_sys_resp_thrd                               [NUM_CLUSTER-1:0];
    logic [THRD_W-1:0]                                  r_sys_host_thrd                               [NUM_CLUSTER-1:0];
    logic [VTID_W-1:0]                                  r_sys_host_vtid                               [NUM_CLUSTER-1:0];
    logic                                               r_sys_host_vtid_valid                         [NUM_CLUSTER-1:0];
    logic [1:0]                                         r_sys_host_priv                               [NUM_CLUSTER-1:0];
    logic [THRD_W-1:0]                                  w_sys_cmd_host_thrd                           [NUM_CLUSTER-1:0];
    logic [VTID_W-1:0]                                  w_sys_cmd_host_vtid                           [NUM_CLUSTER-1:0];
    logic                                               w_sys_cmd_host_valid                          [NUM_CLUSTER-1:0];
    logic [VTID_W-1:0]                                  r_core_active_vtid                            [NUM_CORES-1:0] [NUM_HW_THRDS-1:0];

    /* Router wires */
    logic                                               w_rtr_mem_req_instr_valid                   [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_instr_ready                   [NUM_CORES-1:0] [3:0];
    logic [VIR_ADDR_W-1:0]                              w_rtr_mem_req_instr_addr                    [NUM_CORES-1:0] [3:0];
    logic [CORE_THRD_W-1:0]                             w_rtr_mem_req_instr_thrd_id                 [NUM_CORES-1:0] [3:0];
    logic [1:0]                                         w_rtr_mem_req_instr_priv                    [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_resp_instr_valid                  [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_resp_instr_ready                  [NUM_CORES-1:0] [3:0];
    logic [XLEN-1:0]                                    w_rtr_mem_resp_instr_rdata                  [NUM_CORES-1:0] [3:0];
    logic [CORE_THRD_W-1:0]                             w_rtr_mem_resp_instr_thrd_id                [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_data_valid                    [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_data_ready                    [NUM_CORES-1:0] [3:0];
    logic [VIR_ADDR_W-1:0]                              w_rtr_mem_req_data_addr                     [NUM_CORES-1:0] [3:0];
    logic [CORE_THRD_W-1:0]                             w_rtr_mem_req_data_thrd_id                  [NUM_CORES-1:0] [3:0];
    logic [1:0]                                         w_rtr_mem_req_data_priv                     [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_data_rw                       [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_data_lq                       [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_req_data_sc                       [NUM_CORES-1:0] [3:0];
    logic [XLEN/8-1:0]                                  w_rtr_mem_req_data_wstrb                    [NUM_CORES-1:0] [3:0];
    logic [XLEN-1:0]                                    w_rtr_mem_req_data_wdata                    [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_resp_data_valid                   [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_resp_data_ready                   [NUM_CORES-1:0] [3:0];
    logic [XLEN-1:0]                                    w_rtr_mem_resp_data_rdata                   [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_resp_data_sc_ok                   [NUM_CORES-1:0] [3:0];
    logic [CORE_THRD_W-1:0]                             w_rtr_mem_resp_data_thrd_id                 [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_valid                    [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_ready                    [NUM_CORES-1:0] [3:0];
    logic [PAGE_MSG_W-1:0]                              w_rtr_mem_page_msg                          [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_instr_valid              [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_instr_ready              [NUM_CORES-1:0] [3:0];
    logic [PAGE_MSG_W-1:0]                              w_rtr_mem_page_msg_instr                    [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_data_valid               [NUM_CORES-1:0] [3:0];
    logic                                               w_rtr_mem_page_msg_data_ready               [NUM_CORES-1:0] [3:0];
    logic [PAGE_MSG_W-1:0]                              w_rtr_mem_page_msg_data                     [NUM_CORES-1:0] [3:0];

    // External-event and console wires
    logic [THREADS_PER_CLUSTER-1:0]                    w_cluster_wake_vec   [NUM_CLUSTER-1:0];
    logic [NUM_CORES-1:0]                              w_uart_req_valid_vec;
    logic [NUM_CORES-1:0]                              w_uart_grant;
    logic [$clog2(NUM_CORES > 1 ? NUM_CORES : 2)-1:0] r_uart_resp_core;
    logic [XLEN-1:0]                                   w_core_timer_resp_rdata_mux  [NUM_CORES-1:0];
    logic [CORE_THRD_W-1:0]                            w_core_timer_resp_thrd_mux   [NUM_CORES-1:0];
    logic                                              w_core_timer_resp_valid_any  [NUM_CORES-1:0];
    logic                                              w_core_timer_req_valid_any   [NUM_CORES-1:0];
    logic                                              w_core_ipi_req_valid         [NUM_CORES-1:0];
    logic                                              w_core_oob_req_valid         [NUM_CORES-1:0];
    logic                                              w_core_sys_req_valid         [NUM_CORES-1:0];
    logic                                              w_core_uart_req_valid        [NUM_CORES-1:0];


    /* Module instances */
    page_engine_axi4 page_engine_u (
        .i_clk                  (w_page_clk),
        .i_rst_n                (w_page_rst_n),
        .i_req_we               (w_page_req_we),
        .i_req_valid            (w_page_req_valid),
        .i_req_addr             (w_page_req_addr),
        .i_req_wdata            (w_page_req_wdata),
        .o_req_ready            (w_page_req_ready),
        .i_resp_ready           (w_page_resp_ready),
        .o_resp_valid           (w_page_resp_valid),
        .o_resp_addr            (w_page_resp_addr),
        .o_resp_we              (w_page_resp_we),
        .o_resp_wdata           (w_page_resp_wdata),
        .o_transfer_done        (w_page_transfer_done),
        .m_axi4_page_awaddr     (w_page_m_axi4_page_awaddr),
        .m_axi4_page_awlen      (w_page_m_axi4_page_awlen),
        .m_axi4_page_awsize     (w_page_m_axi4_page_awsize),
        .m_axi4_page_awburst    (w_page_m_axi4_page_awburst),
        .m_axi4_page_awlock     (w_page_m_axi4_page_awlock),
        .m_axi4_page_awcache    (w_page_m_axi4_page_awcache),
        .m_axi4_page_awprot     (w_page_m_axi4_page_awprot),
        .m_axi4_page_awqos      (w_page_m_axi4_page_awqos),
        .m_axi4_page_awregion   (w_page_m_axi4_page_awregion),
        .m_axi4_page_awid       (w_page_m_axi4_page_awid),
        .m_axi4_page_awvalid    (w_page_m_axi4_page_awvalid),
        .m_axi4_page_awready    (w_page_m_axi4_page_awready),
        .m_axi4_page_wdata      (w_page_m_axi4_page_wdata),
        .m_axi4_page_wstrb      (w_page_m_axi4_page_wstrb),
        .m_axi4_page_wlast      (w_page_m_axi4_page_wlast),
        .m_axi4_page_wvalid     (w_page_m_axi4_page_wvalid),
        .m_axi4_page_wready     (w_page_m_axi4_page_wready),
        .m_axi4_page_bresp      (w_page_m_axi4_page_bresp),
        .m_axi4_page_bid        (w_page_m_axi4_page_bid),
        .m_axi4_page_bvalid     (w_page_m_axi4_page_bvalid),
        .m_axi4_page_bready     (w_page_m_axi4_page_bready),
        .m_axi4_page_araddr     (w_page_m_axi4_page_araddr),
        .m_axi4_page_arlen      (w_page_m_axi4_page_arlen),
        .m_axi4_page_arsize     (w_page_m_axi4_page_arsize),
        .m_axi4_page_arburst    (w_page_m_axi4_page_arburst),
        .m_axi4_page_arlock     (w_page_m_axi4_page_arlock),
        .m_axi4_page_arcache    (w_page_m_axi4_page_arcache),
        .m_axi4_page_arprot     (w_page_m_axi4_page_arprot),
        .m_axi4_page_arqos      (w_page_m_axi4_page_arqos),
        .m_axi4_page_arregion   (w_page_m_axi4_page_arregion),
        .m_axi4_page_arid       (w_page_m_axi4_page_arid),
        .m_axi4_page_arvalid    (w_page_m_axi4_page_arvalid),
        .m_axi4_page_arready    (w_page_m_axi4_page_arready),
        .m_axi4_page_rdata      (w_page_m_axi4_page_rdata),
        .m_axi4_page_rresp      (w_page_m_axi4_page_rresp),
        .m_axi4_page_rlast      (w_page_m_axi4_page_rlast),
        .m_axi4_page_rid        (w_page_m_axi4_page_rid),
        .m_axi4_page_rvalid     (w_page_m_axi4_page_rvalid),
        .m_axi4_page_rready     (w_page_m_axi4_page_rready)
    );

    reset_sync fabric_reset_sync (
        .i_clk         (i_clk),
        .i_async_rst_n (i_rst_n),
        .o_rst_n       (rst_fabric_n)
    );

    // The accelerator/system-core and peripheral domains are independently
    // resettable even though the current implementation uses i_clk for all
    // domains.  This keeps reset release local when a domain later receives
    // its own clock.
    reset_sync accel_reset_sync (
        .i_clk         (i_clk),
        .i_async_rst_n (i_rst_n),
        .o_rst_n       (rst_accel_n)
    );
    reset_sync periph_reset_sync (
        .i_clk         (i_clk),
        .i_async_rst_n (i_rst_n),
        .o_rst_n       (rst_periph_n)
    );
    for (genvar cl = 0; cl < NUM_CLUSTER; cl++) begin : gen_cluster_reset
        reset_sync cluster_reset_sync (
            .i_clk         (i_clk),
            .i_async_rst_n (i_rst_n),
            .o_rst_n       (rst_cluster_n[cl])
        );
    end
    for (genvar m = 0; m < NUM_MEM; m++) begin : gen_memory_reset
        reset_sync memory_reset_sync (
            .i_clk         (i_clk),
            .i_async_rst_n (i_rst_n),
            .o_rst_n       (rst_mem_n[m])
        );
    end
    generate
        for(genvar i = 0; i < NUM_CLUSTER; i++) begin : gen_cluster
            for (genvar j = 0; j < CORES_PER_CLUSTER; j++) begin : gen_core
                core #(
                .RESET_VEC(reset_vector(i))
                ) core_u (
                .i_clk                                  (w_core_clk                                     [i*CORES_PER_CLUSTER+j]),
                .i_rst_n                                (w_core_rst_n                                   [i*CORES_PER_CLUSTER+j]),
                .i_thrd_id_vec                          (w_core_thrd_id_vec                             [i*CORES_PER_CLUSTER+j]),   
                .i_wake_intr_vec                        (w_core_wake_intr_vec                           [i*CORES_PER_CLUSTER+j]),
                .i_irq_timer_vec                        (w_core_irq_timer_vec                           [i*CORES_PER_CLUSTER+j]),
                .i_req_instr_ready                      (w_core_req_instr_ready                         [i*CORES_PER_CLUSTER+j]),
                .o_req_instr_addr                       (w_core_req_instr_addr                          [i*CORES_PER_CLUSTER+j]),
                .o_req_instr_thrd_id                    (w_core_req_instr_thrd_id                       [i*CORES_PER_CLUSTER+j]),
                .o_req_instr_valid                      (w_core_req_instr_valid                         [i*CORES_PER_CLUSTER+j]),
                .o_req_instr_priv                       (w_core_req_instr_priv                          [i*CORES_PER_CLUSTER+j]),
                .o_resp_instr_ready                     (w_core_resp_instr_ready                        [i*CORES_PER_CLUSTER+j]),
                .i_resp_instr                           (w_core_resp_instr                              [i*CORES_PER_CLUSTER+j]),
                .i_resp_instr_thrd_id                   (w_core_resp_instr_thrd_id                      [i*CORES_PER_CLUSTER+j]),
                .i_resp_instr_valid                     (w_core_resp_instr_valid                        [i*CORES_PER_CLUSTER+j]),
                .i_req_data_ready                       (w_core_req_data_ready                          [i*CORES_PER_CLUSTER+j]),
                .o_req_data_addr                        (w_core_req_data_addr                           [i*CORES_PER_CLUSTER+j]),
                .o_req_data_thrd_id                     (w_core_req_data_thrd_id                        [i*CORES_PER_CLUSTER+j]),
                .o_req_data_priv                        (w_core_req_data_priv                           [i*CORES_PER_CLUSTER+j]),
                .o_req_data_rw                          (w_core_req_data_rw                             [i*CORES_PER_CLUSTER+j]),
                .o_req_data_lq                          (w_core_req_data_lq                             [i*CORES_PER_CLUSTER+j]),
                .o_req_data_sc                          (w_core_req_data_sc                             [i*CORES_PER_CLUSTER+j]),
                .o_req_data_wstrb                       (w_core_req_data_wstrb                          [i*CORES_PER_CLUSTER+j]),
                .o_req_data_wdata                       (w_core_req_data_wdata                          [i*CORES_PER_CLUSTER+j]),
                .o_req_data_valid                       (w_core_req_data_valid                          [i*CORES_PER_CLUSTER+j]),
                .o_resp_data_ready                      (w_core_resp_data_ready                         [i*CORES_PER_CLUSTER+j]),
                .i_resp_data_rdata                      (w_core_resp_data_rdata                         [i*CORES_PER_CLUSTER+j]),
                .i_resp_data_sc_ok                      (w_core_resp_data_sc_ok                         [i*CORES_PER_CLUSTER+j]),
                .i_resp_data_thrd_id                    (w_core_resp_data_thrd_id                       [i*CORES_PER_CLUSTER+j]),
                .i_resp_data_valid                      (w_core_resp_data_valid                         [i*CORES_PER_CLUSTER+j]),
                .i_page_msg_instr_valid                 (w_core_page_msg_instr_valid                  [i*CORES_PER_CLUSTER+j]),
                .i_page_msg_instr                       (w_core_page_msg_instr                        [i*CORES_PER_CLUSTER+j]),
                .o_page_msg_instr_ready                 (w_core_page_msg_instr_ready                    [i*CORES_PER_CLUSTER+j]),
                .i_page_msg_data_valid                  (w_core_page_msg_data_valid                   [i*CORES_PER_CLUSTER+j]),
                .i_page_msg_data                        (w_core_page_msg_data                         [i*CORES_PER_CLUSTER+j]),
                .o_page_msg_data_ready                  (w_core_page_msg_data_ready                     [i*CORES_PER_CLUSTER+j]),
                .o_page_msg_valid                       (w_core_page_msg_valid                          [i*CORES_PER_CLUSTER+j]),
                .o_page_msg                             (w_core_page_msg                                [i*CORES_PER_CLUSTER+j]),
                .i_page_msg_ready                       (w_core_page_msg_ready                          [i*CORES_PER_CLUSTER+j])
            );

            for (genvar t = 0; t < NUM_HW_THRDS; t++) begin : gen_timers
                timer timer_inst (
                    .clk_i       (w_core_clk[i*CORES_PER_CLUSTER+j]),
                    .rst_ni      (w_core_rst_n[i*CORES_PER_CLUSTER+j]),
                    .req_valid_i (w_core_timer_req_valid[i*CORES_PER_CLUSTER+j][t]),
                    .req_addr_i  (w_router_mmio_req_addr[i*CORES_PER_CLUSTER+j]),
                    .req_we_i    (w_router_mmio_req_rw[i*CORES_PER_CLUSTER+j]),
                    .req_wstrb_i (w_router_mmio_req_wstrb[i*CORES_PER_CLUSTER+j]),
                    .req_wdata_i (w_router_mmio_req_wdata[i*CORES_PER_CLUSTER+j]),
                    .req_ready_o (w_core_timer_req_ready[i*CORES_PER_CLUSTER+j][t]),
                    .resp_valid_o(w_core_timer_resp_valid[i*CORES_PER_CLUSTER+j][t]),
                    .resp_ready_i(w_core_timer_resp_ready[i*CORES_PER_CLUSTER+j][t]),
                    .resp_rdata_o(w_core_timer_resp_rdata[i*CORES_PER_CLUSTER+j][t]),
                    .irq_timer_o (w_core_irq_timer_vec[i*CORES_PER_CLUSTER+j][t])
                );
            end

            end
            memory #(.REGION_ID(i)) memory_u (
                .i_clk                                  (w_memory_clk                                   [i]),
                .i_rst_n                                (w_memory_rst_n                                 [i]),
                .i_req_we                               (w_memory_req_we                                [i]),
                .i_req_thrd                             (w_memory_req_thrd                              [i]),
                .i_req_is_lr                            (w_memory_req_is_lr                             [i]),
                .i_req_is_sc                            (w_memory_req_is_sc                             [i]),
                .i_req_addr                             (w_memory_req_addr                              [i]),
                .i_req_wstrb                            (w_memory_req_wstrb                             [i]),
                .i_req_wdata                            (w_memory_req_wdata                             [i]),
                .i_req_valid                            (w_memory_req_valid                             [i]),
                .i_req_priv                             (w_memory_req_priv                              [i]),
                .o_req_ready                            (w_memory_req_ready                             [i]),
                .o_resp_thrd                            (w_memory_resp_thrd                             [i]),
                .o_resp_sc_succ                         (w_memory_resp_sc_succ                          [i]),
                .o_resp_rdata                           (w_memory_resp_rdata                            [i]),
                .o_resp_valid                           (w_memory_resp_valid                            [i]),
                .i_resp_ready                           (w_memory_resp_ready                            [i]),
                .i_page_msg_valid                       (w_memory_page_msg_valid                        [i]),
                .o_page_msg_ready                       (w_memory_page_msg_ready                        [i]),
                .i_page_msg                             (w_memory_page_msg                              [i]),
                .i_page_msg_ready                       (w_memory_o_page_msg_ready                      [i]),
                .o_page_msg_valid                       (w_memory_o_page_msg_valid                      [i]),
                .o_page_msg                             (w_memory_o_page_msg                            [i]),
                .o_page_req_we                          (w_memory_page_req_we                           [i]),
                .o_page_req_valid                       (w_memory_page_req_valid                        [i]),
                .i_page_req_ready                       (w_memory_page_req_ready                        [i]),
                .o_page_req_addr                        (w_memory_page_req_addr                         [i]),
                .o_page_req_wdata                       (w_memory_page_req_wdata                        [i]),
                .i_page_resp_addr                       (w_memory_page_resp_addr                        [i]),
                .i_page_resp_we                         (w_memory_page_resp_we                          [i]),
                .i_page_resp_wdata                      (w_memory_page_resp_wdata                       [i]),
                .i_page_resp_valid                      (w_memory_page_resp_valid                       [i]),
                .o_page_resp_ready                      (w_memory_page_resp_ready                       [i]),
                .i_page_transfer_done                   (w_memory_page_transfer_done                    [i]),
                .o_page_completion_pending              (w_memory_page_completion_pending               [i]),
                .o_page_completion_thrd                 (w_memory_page_completion_thrd                  [i])
            );
            if (topology_pkg::SYS_CORES_PER_CLUSTER > 0) begin : gen_sys_core_enabled
            sys_core sys_core_u (
                .i_clk                                  (i_clk),
                .i_rst_n                                (rst_accel_n),
                .i_mmio_req_valid                       (w_sys_mmio_req_valid                          [i]),
                .o_mmio_req_ready                       (w_sys_mmio_req_ready                          [i]),
                .i_mmio_req_addr                        (w_sys_mmio_req_addr                           [i]),
                .i_mmio_req_wdata                       (w_sys_mmio_req_wdata                          [i]),
                .i_mmio_req_wmask                       (w_sys_mmio_req_wmask                          [i]),
                .o_mmio_resp_valid                      (w_sys_mmio_resp_valid                         [i]),
                .o_mmio_resp_rdata                      (w_sys_mmio_resp_rdata                         [i]),
                .i_mmio_resp_ready                      (w_sys_mmio_resp_ready                         [i]),
                .i_host_thrd                            (r_sys_host_thrd                               [i]),
                .o_intr                                 (w_sys_intr                                    [i]),
                .o_intr_thrd                            (w_sys_intr_thrd                               [i]),
                .o_req_we                               (w_sys_req_we                                  [i]),
                .o_req_thrd                             (w_sys_req_thrd                                [i]),
                .o_req_is_lr                            (w_sys_req_is_lr                               [i]),
                .o_req_is_sc                            (w_sys_req_is_sc                               [i]),
                .o_req_addr                             (w_sys_req_addr                                [i]),
                .o_req_wstrb                            (w_sys_req_wstrb                               [i]),
                .o_req_wdata                            (w_sys_req_wdata                               [i]),
                .o_req_valid                            (w_sys_req_valid                               [i]),
                .i_req_ready                            (w_sys_req_ready                               [i]),
                .i_resp_thrd                            (w_sys_resp_thrd                               [i]),
                .i_resp_sc_succ                         (w_sys_resp_sc_succ                            [i]),
                .i_resp_rdata                           (w_sys_resp_rdata                              [i]),
                .i_resp_valid                           (w_sys_resp_valid                              [i]),
                .o_resp_ready                           (w_sys_resp_ready                              [i])
            );
            end
        end
    endgenerate

    uart_mmio #(
        .BASE_ADDR                                      (UART_BASE_ADDR),
        .RX_DEPTH                                       (1024),
        .TX_DEPTH                                       (1024)
    ) uart_mmio_inst (
        .i_clk                                          (w_uart_mmio_clk),
        .i_rst_n                                        (w_uart_mmio_rst_n),
        .i_req_we                                       (w_uart_mmio_req_we),
        .i_req_thrd                                     (w_uart_mmio_req_thrd),
        .i_req_is_lr                                    (w_uart_mmio_req_is_lr),
        .i_req_is_sc                                    (w_uart_mmio_req_is_sc),
        .i_req_addr                                     (w_uart_mmio_req_addr),
        .i_req_wstrb                                    (w_uart_mmio_req_wstrb),
        .i_req_wdata                                    (w_uart_mmio_req_wdata),
        .i_req_valid                                    (w_uart_mmio_req_valid),
        .i_req_priv                                     (w_uart_mmio_req_priv),
        .o_req_ready                                    (w_uart_mmio_req_ready),
        .o_resp_thrd                                    (w_uart_mmio_resp_thrd),
        .o_resp_sc_succ                                 (w_uart_mmio_resp_sc_succ),
        .o_resp_rdata                                   (w_uart_mmio_resp_rdata),
        .o_resp_valid                                   (w_uart_mmio_resp_valid),
        .i_resp_ready                                   (w_uart_mmio_resp_ready),
        .i_rx                                           (w_uart_mmio_rx),
        .o_tx                                           (w_uart_mmio_tx)
    );
    /* ---*/

    /* Router instances */
    generate
	    for (genvar c = 0; c < NUM_CORES; c++) begin : gen_routers
	        localparam int CLUSTER_ID = core_cluster_id(c);
	        localparam int C_X = cluster_x(CLUSTER_ID);
	        localparam int C_Y = cluster_y(CLUSTER_ID);
            
            router #(
                .C_X(C_X),
                .C_Y(C_Y)
            ) router_u (
                .i_clk(i_clk),
                .i_rst_n(rst_fabric_n),
                .i_req_instr_valid(w_core_req_instr_valid[c]),
                .o_req_instr_ready(w_core_req_instr_ready[c]),
                .i_req_instr_addr(w_core_req_instr_addr[c]),
                .i_req_instr_thrd_id(w_core_req_instr_thrd_id[c]),
                .i_req_instr_priv(w_core_req_instr_priv[c]),
                
                .o_resp_instr_valid(w_core_resp_instr_valid[c]),
                .i_resp_instr_ready(w_core_resp_instr_ready[c]),
                .o_resp_instr(w_core_resp_instr[c]),
                .o_resp_instr_thrd_id(w_core_resp_instr_thrd_id[c]),

                .i_req_data_valid(w_core_req_data_valid[c]),
                .o_req_data_ready(w_core_req_data_ready[c]),
                .i_req_data_addr(w_core_req_data_addr[c]),
                .i_req_data_thrd_id(w_core_req_data_thrd_id[c]),
                .i_req_data_priv(w_core_req_data_priv[c]),
                .i_req_data_rw(w_core_req_data_rw[c]),
                .i_req_data_lq(w_core_req_data_lq[c]),
                .i_req_data_sc(w_core_req_data_sc[c]),
                .i_req_data_wstrb(w_core_req_data_wstrb[c]),
                .i_req_data_wdata(w_core_req_data_wdata[c]),
                
                .o_resp_data_valid(w_core_resp_data_valid[c]),
                .i_resp_data_ready(w_core_resp_data_ready[c]),
                .o_resp_data_rdata(w_core_resp_data_rdata[c]),
                .o_resp_data_sc_ok(w_core_resp_data_sc_ok[c]),
                .o_resp_data_thrd_id(w_core_resp_data_thrd_id[c]),
                .o_mmio_req_valid(w_router_mmio_req_valid[c]),
                .i_mmio_req_ready(w_router_mmio_req_ready[c]),
                .o_mmio_req_addr(w_router_mmio_req_addr[c]),
                .o_mmio_req_thrd_id(w_router_mmio_req_thrd_id[c]),
                .o_mmio_req_priv(w_router_mmio_req_priv[c]),
                .o_mmio_req_rw(w_router_mmio_req_rw[c]),
                .o_mmio_req_wstrb(w_router_mmio_req_wstrb[c]),
                .o_mmio_req_wdata(w_router_mmio_req_wdata[c]),
                .i_mmio_resp_valid(w_router_mmio_resp_valid[c]),
                .o_mmio_resp_ready(w_router_mmio_resp_ready[c]),
                .i_mmio_resp_rdata(w_router_mmio_resp_rdata[c]),
                .i_mmio_resp_sc_ok(w_router_mmio_resp_sc_ok[c]),
                .i_mmio_resp_thrd_id(w_router_mmio_resp_thrd_id[c]),
                .i_core_page_msg_valid(w_core_page_msg_valid[c]),
                .i_core_page_msg(w_core_page_msg[c]),
                .o_core_page_msg_ready(w_core_page_msg_ready[c]),
                .o_core_page_msg_instr_valid(w_core_page_msg_instr_valid[c]),
                .o_core_page_msg_instr(w_core_page_msg_instr[c]),
                .i_core_page_msg_instr_ready(w_core_page_msg_instr_ready[c]),
                .o_core_page_msg_data_valid(w_core_page_msg_data_valid[c]),
                .o_core_page_msg_data(w_core_page_msg_data[c]),
                .i_core_page_msg_data_ready(w_core_page_msg_data_ready[c]),
                .o_mem_page_msg_valid(w_rtr_mem_page_msg_valid[c]),
                .o_mem_page_msg(w_rtr_mem_page_msg[c]),
                .i_mem_page_msg_ready(w_rtr_mem_page_msg_ready[c]),
                .i_mem_page_msg_instr_valid(w_rtr_mem_page_msg_instr_valid[c]),
                .i_mem_page_msg_instr(w_rtr_mem_page_msg_instr[c]),
                .o_mem_page_msg_instr_ready(w_rtr_mem_page_msg_instr_ready[c]),
                .i_mem_page_msg_data_valid(w_rtr_mem_page_msg_data_valid[c]),
                .i_mem_page_msg_data(w_rtr_mem_page_msg_data[c]),
                .o_mem_page_msg_data_ready(w_rtr_mem_page_msg_data_ready[c]),

                .o_mem_req_instr_valid(w_rtr_mem_req_instr_valid[c]),
                .i_mem_req_instr_ready(w_rtr_mem_req_instr_ready[c]),
                .o_mem_req_instr_addr(w_rtr_mem_req_instr_addr[c]),
                .o_mem_req_instr_thrd_id(w_rtr_mem_req_instr_thrd_id[c]),
                .o_mem_req_instr_priv(w_rtr_mem_req_instr_priv[c]),
                
                .i_mem_resp_instr_valid(w_rtr_mem_resp_instr_valid[c]),
                .o_mem_resp_instr_ready(w_rtr_mem_resp_instr_ready[c]),
                .i_mem_resp_instr_rdata(w_rtr_mem_resp_instr_rdata[c]),
                .i_mem_resp_instr_thrd_id(w_rtr_mem_resp_instr_thrd_id[c]),

                .o_mem_req_data_valid(w_rtr_mem_req_data_valid[c]),
                .i_mem_req_data_ready(w_rtr_mem_req_data_ready[c]),
                .o_mem_req_data_addr(w_rtr_mem_req_data_addr[c]),
                .o_mem_req_data_thrd_id(w_rtr_mem_req_data_thrd_id[c]),
                .o_mem_req_data_priv(w_rtr_mem_req_data_priv[c]),
                .o_mem_req_data_rw(w_rtr_mem_req_data_rw[c]),
                .o_mem_req_data_lq(w_rtr_mem_req_data_lq[c]),
                .o_mem_req_data_sc(w_rtr_mem_req_data_sc[c]),
                .o_mem_req_data_wstrb(w_rtr_mem_req_data_wstrb[c]),
                .o_mem_req_data_wdata(w_rtr_mem_req_data_wdata[c]),
                
                .i_mem_resp_data_valid(w_rtr_mem_resp_data_valid[c]),
                .o_mem_resp_data_ready(w_rtr_mem_resp_data_ready[c]),
                .i_mem_resp_data_rdata(w_rtr_mem_resp_data_rdata[c]),
                .i_mem_resp_data_sc_ok(w_rtr_mem_resp_data_sc_ok[c]),
                .i_mem_resp_data_thrd_id(w_rtr_mem_resp_data_thrd_id[c])
            );

        end
    endgenerate

    /* Logic */

    /* Page engine */
    assign w_page_clk                 = i_clk;
    assign w_page_rst_n               = rst_accel_n;
    assign w_page_req_we              = w_memory_page_req_we[0];
    assign w_page_req_valid           = w_memory_page_req_valid[0];
    assign w_page_req_addr            = w_memory_page_req_addr[0];
    assign w_page_req_wdata           = w_memory_page_req_wdata[0];
    assign w_memory_page_req_ready[0]   = w_page_req_ready;
    assign w_page_resp_ready          = w_memory_page_resp_ready[0];
    assign w_memory_page_resp_valid[0]  = w_page_resp_valid;
    assign w_memory_page_resp_addr[0]   = w_page_resp_addr;
    assign w_memory_page_resp_we[0]     = w_page_resp_we;
    assign w_memory_page_resp_wdata[0]  = w_page_resp_wdata;
    assign w_memory_page_transfer_done[0] = w_page_transfer_done;
    assign m_axi4_page_awaddr           = w_page_m_axi4_page_awaddr;
    assign m_axi4_page_awlen            = w_page_m_axi4_page_awlen;
    assign m_axi4_page_awsize           = w_page_m_axi4_page_awsize;
    assign m_axi4_page_awburst          = w_page_m_axi4_page_awburst;
    assign m_axi4_page_awlock           = w_page_m_axi4_page_awlock;
    assign m_axi4_page_awcache          = w_page_m_axi4_page_awcache;
    assign m_axi4_page_awprot           = w_page_m_axi4_page_awprot;
    assign m_axi4_page_awqos            = w_page_m_axi4_page_awqos;
    assign m_axi4_page_awregion         = w_page_m_axi4_page_awregion;
    assign m_axi4_page_awid             = w_page_m_axi4_page_awid;
    assign m_axi4_page_awvalid          = w_page_m_axi4_page_awvalid;
    assign w_page_m_axi4_page_awready   = m_axi4_page_awready;
    assign m_axi4_page_wdata            = w_page_m_axi4_page_wdata;
    assign m_axi4_page_wstrb            = w_page_m_axi4_page_wstrb;
    assign m_axi4_page_wlast            = w_page_m_axi4_page_wlast;
    assign m_axi4_page_wvalid           = w_page_m_axi4_page_wvalid;
    assign w_page_m_axi4_page_wready    = m_axi4_page_wready;
    assign w_page_m_axi4_page_bresp     = m_axi4_page_bresp;
    assign w_page_m_axi4_page_bid       = m_axi4_page_bid;
    assign w_page_m_axi4_page_bvalid    = m_axi4_page_bvalid;
    assign m_axi4_page_bready           = w_page_m_axi4_page_bready;
    assign m_axi4_page_araddr           = w_page_m_axi4_page_araddr;
    assign m_axi4_page_arlen            = w_page_m_axi4_page_arlen;
    assign m_axi4_page_arsize           = w_page_m_axi4_page_arsize;
    assign m_axi4_page_arburst          = w_page_m_axi4_page_arburst;
    assign m_axi4_page_arlock           = w_page_m_axi4_page_arlock;
    assign m_axi4_page_arcache          = w_page_m_axi4_page_arcache;
    assign m_axi4_page_arprot           = w_page_m_axi4_page_arprot;
    assign m_axi4_page_arqos            = w_page_m_axi4_page_arqos;
    assign m_axi4_page_arregion         = w_page_m_axi4_page_arregion;
    assign m_axi4_page_arid             = w_page_m_axi4_page_arid;
    assign m_axi4_page_arvalid          = w_page_m_axi4_page_arvalid;
    assign w_page_m_axi4_page_arready   = m_axi4_page_arready;
    assign w_page_m_axi4_page_rdata     = m_axi4_page_rdata;
    assign w_page_m_axi4_page_rresp     = m_axi4_page_rresp;
    assign w_page_m_axi4_page_rlast     = m_axi4_page_rlast;
    assign w_page_m_axi4_page_rid       = m_axi4_page_rid;
    assign w_page_m_axi4_page_rvalid    = m_axi4_page_rvalid;
    assign m_axi4_page_rready           = w_page_m_axi4_page_rready;

    if (topology_pkg::SYS_CORES_PER_CLUSTER == 0) begin : gen_sys_core_disabled
        for (genvar cl = 0; cl < NUM_CLUSTER; cl++) begin
            assign w_sys_mmio_req_ready[cl] = 1'b0;
            assign w_sys_mmio_resp_valid[cl] = 1'b0;
            assign w_sys_mmio_resp_rdata[cl] = '0;
            assign w_sys_intr[cl] = 1'b0;
            assign w_sys_intr_thrd[cl] = '0;
        end
    end

    for (genvar c = 0; c < NUM_CORES; c++) begin : gen_timer_wiring
        for (genvar t = 0; t < NUM_HW_THRDS; t++) begin
            assign w_core_timer_req_valid[c][t] = w_router_mmio_req_valid[c] && is_timer_mmio_addr(w_router_mmio_req_addr[c], w_router_mmio_req_priv[c]) && w_router_mmio_req_thrd_id[c] == t;
            assign w_core_timer_resp_ready[c][t] = w_router_mmio_resp_ready[c] &&
                                                   !r_ipi_resp_valid[c] && !r_oob_resp_valid[c] &&
                                                   w_core_timer_resp_valid_any[c] &&
                                                   w_core_timer_resp_thrd_mux[c] == CORE_THRD_W'(t);
        end
    end

    /* Sys-array MMIO */
    always_comb begin
        w_sys_mmio_grant = '0;
        for (int cl = 0; cl < NUM_CLUSTER; cl++) begin
            w_sys_mmio_req_valid[cl]  = 1'b0;
            w_sys_mmio_req_addr[cl]   = '0;
            w_sys_mmio_req_wdata[cl]  = '0;
            w_sys_mmio_req_wmask[cl]  = '0;
            w_sys_mmio_resp_ready[cl] = 1'b0;
            w_sys_cmd_host_thrd[cl]   = r_sys_host_thrd[cl];
            w_sys_cmd_host_vtid[cl]   = r_sys_host_vtid[cl];
            w_sys_cmd_host_valid[cl]  = 1'b0;
            for (int k = 0; k < CORES_PER_CLUSTER; k++) begin
                int c = cluster_core_id(cl, k);
                if (w_router_mmio_req_valid[c] && is_sys_mmio_addr(w_router_mmio_req_addr[c], w_router_mmio_req_priv[c]) && !w_sys_mmio_req_valid[cl]) begin
                    w_sys_mmio_grant[c]      = 1'b1;
                    w_sys_mmio_req_valid[cl] = 1'b1;
                    w_sys_mmio_req_addr[cl]  = w_router_mmio_req_addr[c];
                    w_sys_mmio_req_wdata[cl] = w_router_mmio_req_wdata[c];
                    w_sys_mmio_req_wmask[cl] = w_router_mmio_req_wstrb[c];
                    w_sys_cmd_host_thrd[cl]  = memory_thread_id(c, w_router_mmio_req_thrd_id[c]);
                    w_sys_cmd_host_vtid[cl]  = r_core_active_vtid[c][w_router_mmio_req_thrd_id[c]];
                    w_sys_cmd_host_valid[cl] = w_router_mmio_req_rw[c] && (w_router_mmio_req_wstrb[c] != '0) && (w_router_mmio_req_addr[c][7:0] == 8'h08) && (w_sys_mmio_req_wdata[cl][31:24] == 8'h03) && w_sys_mmio_req_ready[cl];
                end
                if (r_sys_resp_core[cl] == $bits(r_sys_resp_core[cl])'(k)) w_sys_mmio_resp_ready[cl] = w_router_mmio_resp_ready[c];
            end
        end
    end

    /* Router-memory fabric */
    always_comb begin
        // default all memory ports to unused
        for (int m = 0; m < NUM_MEM; m++) begin
            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                w_memory_req_valid[m][p] = 1'b0;
                w_memory_req_addr[m][p]  = '0;
                w_memory_req_thrd[m][p]  = '0;
                w_memory_req_priv[m][p]  = 2'b11;
                w_memory_req_we[m][p]    = 1'b0;
                w_memory_req_is_lr[m][p] = 1'b0;
                w_memory_req_is_sc[m][p] = 1'b0;
                w_memory_req_wstrb[m][p] = '0;
                w_memory_req_wdata[m][p] = '0;
                
                w_memory_resp_ready[m][p] = 1'b0;

                w_memory_page_msg_valid[m][p]   = 1'b0;
                w_memory_page_msg[m][p]         = '0;
                w_memory_o_page_msg_ready[m][p] = 1'b0;
            end
        end
        // default all router mem interfaces to unused
        for (int c = 0; c < NUM_CORES; c++) begin
            for (int i = 0; i < 4; i++) begin
                w_rtr_mem_req_instr_ready[c][i] = 1'b0;
                w_rtr_mem_resp_instr_valid[c][i] = 1'b0;
                w_rtr_mem_resp_instr_rdata[c][i] = '0;
                w_rtr_mem_resp_instr_thrd_id[c][i] = '0;
                
                w_rtr_mem_req_data_ready[c][i] = 1'b0;
                w_rtr_mem_resp_data_valid[c][i] = 1'b0;
                w_rtr_mem_resp_data_rdata[c][i] = '0;
                w_rtr_mem_resp_data_sc_ok[c][i] = 1'b0;
                w_rtr_mem_resp_data_thrd_id[c][i] = '0;
                w_rtr_mem_page_msg_ready[c][i] = 1'b0;
                w_rtr_mem_page_msg_instr_valid[c][i] = 1'b0;
                w_rtr_mem_page_msg_instr[c][i] = '0;
                w_rtr_mem_page_msg_data_valid[c][i] = 1'b0;
                w_rtr_mem_page_msg_data[c][i] = '0;
            end
        end
        for (int cl = 0; cl < NUM_CLUSTER; cl++) begin
            for (int sp = 0; sp < NUM_SYS_PORTS; sp++) begin
                w_sys_req_ready[cl][sp]   = 1'b0;
                w_sys_resp_thrd[cl][sp]   = '0;
                w_sys_resp_sc_succ[cl][sp] = 1'b0;
                w_sys_resp_rdata[cl][sp]  = '0;
                w_sys_resp_valid[cl][sp]  = 1'b0;
            end
        end

        for (int c = 0; c < NUM_CORES; c++) begin
            for (int direction = 0; direction < NUM_CARDINAL_DIRS; direction++) begin
                int mem = neighbor_memory_id(c, direction);
                int instr_port = neighbor_memory_port(c, direction, 1'b0);
                int data_port = neighbor_memory_port(c, direction, 1'b1);

                if (mem != -1) begin
                    w_memory_req_valid[mem][instr_port] = w_rtr_mem_req_instr_valid[c][direction];
                    w_memory_req_addr[mem][instr_port] = memory_req_addr(
                        w_rtr_mem_req_instr_addr[c][direction],
                        w_rtr_mem_req_instr_priv[c][direction]
                    );
                    w_memory_req_thrd[mem][instr_port] =
                        memory_thread_id(c, w_rtr_mem_req_instr_thrd_id[c][direction]);
                    w_memory_req_priv[mem][instr_port] = w_rtr_mem_req_instr_priv[c][direction];
                    w_rtr_mem_req_instr_ready[c][direction] = w_memory_req_ready[mem][instr_port];

                    w_rtr_mem_resp_instr_valid[c][direction] = w_memory_resp_valid[mem][instr_port];
                    w_memory_resp_ready[mem][instr_port] = w_rtr_mem_resp_instr_ready[c][direction];
                    w_rtr_mem_resp_instr_rdata[c][direction] = w_memory_resp_rdata[mem][instr_port];
                    w_rtr_mem_resp_instr_thrd_id[c][direction] =
                        core_thread_id(w_memory_resp_thrd[mem][instr_port]);
                    w_rtr_mem_page_msg_instr_valid[c][direction] = w_memory_o_page_msg_valid[mem][instr_port];
                    w_rtr_mem_page_msg_instr[c][direction] = w_memory_o_page_msg[mem][instr_port];
                    w_memory_o_page_msg_ready[mem][instr_port] = w_rtr_mem_page_msg_instr_ready[c][direction];

                    w_memory_req_valid[mem][data_port] = w_rtr_mem_req_data_valid[c][direction];
                    w_memory_req_addr[mem][data_port] = memory_req_addr(
                        w_rtr_mem_req_data_addr[c][direction],
                        w_rtr_mem_req_data_priv[c][direction]
                    );
                    w_memory_req_thrd[mem][data_port] =
                        memory_thread_id(c, w_rtr_mem_req_data_thrd_id[c][direction]);
                    w_memory_req_priv[mem][data_port] = w_rtr_mem_req_data_priv[c][direction];
                    w_memory_req_we[mem][data_port] = w_rtr_mem_req_data_rw[c][direction];
                    w_memory_req_is_lr[mem][data_port] = w_rtr_mem_req_data_lq[c][direction];
                    w_memory_req_is_sc[mem][data_port] = w_rtr_mem_req_data_sc[c][direction];
                    w_memory_req_wstrb[mem][data_port] = w_rtr_mem_req_data_wstrb[c][direction];
                    w_memory_req_wdata[mem][data_port] = w_rtr_mem_req_data_wdata[c][direction];
                    w_rtr_mem_req_data_ready[c][direction] = w_memory_req_ready[mem][data_port];

                    w_rtr_mem_resp_data_valid[c][direction] = w_memory_resp_valid[mem][data_port];
                    w_memory_resp_ready[mem][data_port] = w_rtr_mem_resp_data_ready[c][direction];
                    w_rtr_mem_resp_data_rdata[c][direction] = w_memory_resp_rdata[mem][data_port];
                    w_rtr_mem_resp_data_sc_ok[c][direction] = w_memory_resp_sc_succ[mem][data_port];
                    w_rtr_mem_resp_data_thrd_id[c][direction] =
                        core_thread_id(w_memory_resp_thrd[mem][data_port]);
                    w_memory_page_msg_valid[mem][data_port] = w_rtr_mem_page_msg_valid[c][direction];
                    w_memory_page_msg[mem][data_port] = w_rtr_mem_page_msg[c][direction];
                    w_rtr_mem_page_msg_ready[c][direction] = w_memory_page_msg_ready[mem][data_port];
                    w_rtr_mem_page_msg_data_valid[c][direction] = w_memory_o_page_msg_valid[mem][data_port];
                    w_rtr_mem_page_msg_data[c][direction] = w_memory_o_page_msg[mem][data_port];
                    w_memory_o_page_msg_ready[mem][data_port] = w_rtr_mem_page_msg_data_ready[c][direction];
                end
            end
        end

        for (int cl = 0; cl < NUM_CLUSTER; cl++) begin
            int M_BOOT = cluster_home_memory_id(cl);
            if (M_BOOT != -1) begin
                for (int sp = 0; sp < NUM_SYS_PORTS; sp++) begin
                    w_memory_req_valid[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_req_valid[cl][sp] && !w_sys_cmd_host_valid[cl] && !r_sys_host_vtid_valid[cl];
                    w_memory_req_addr[M_BOOT][NUM_CPU_RW_PORTS + sp]  = memory_req_addr(w_sys_req_addr[cl][sp], r_sys_host_priv[cl]);
                    w_memory_req_thrd[M_BOOT][NUM_CPU_RW_PORTS + sp]  = THRD_W'(w_sys_req_thrd[cl][sp]);
                    w_memory_req_priv[M_BOOT][NUM_CPU_RW_PORTS + sp]  = r_sys_host_priv[cl];
                    w_memory_req_we[M_BOOT][NUM_CPU_RW_PORTS + sp]    = w_sys_req_we[cl][sp];
                    w_memory_req_is_lr[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_req_is_lr[cl][sp];
                    w_memory_req_is_sc[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_req_is_sc[cl][sp];
                    w_memory_req_wstrb[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_req_wstrb[cl][sp];
                    w_memory_req_wdata[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_req_wdata[cl][sp];
                    w_sys_req_ready[cl][sp] = !w_sys_cmd_host_valid[cl] && !r_sys_host_vtid_valid[cl] && w_memory_req_ready[M_BOOT][NUM_CPU_RW_PORTS + sp];
                    w_memory_page_msg_valid[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_cmd_host_valid[cl] || r_sys_host_vtid_valid[cl];
                    w_memory_page_msg[M_BOOT][NUM_CPU_RW_PORTS + sp]       = PAGE_MSG_W'(vtid_update_msg_t'{
                        padding: '0,
                        vtid: w_sys_cmd_host_valid[cl] ? w_sys_cmd_host_vtid[cl] : r_sys_host_vtid[cl],
                        thrd_id: w_sys_cmd_host_valid[cl] ? w_sys_cmd_host_thrd[cl] : r_sys_host_thrd[cl],
                        msg_type: PAGE_MSG_VTID_UPDATE
                    });

                    w_sys_resp_valid[cl][sp] = w_memory_resp_valid[M_BOOT][NUM_CPU_RW_PORTS + sp];
                    w_sys_resp_rdata[cl][sp] = w_memory_resp_rdata[M_BOOT][NUM_CPU_RW_PORTS + sp];
                    w_sys_resp_sc_succ[cl][sp] = w_memory_resp_sc_succ[M_BOOT][NUM_CPU_RW_PORTS + sp];
                    w_sys_resp_thrd[cl][sp] = XLEN'(w_memory_resp_thrd[M_BOOT][NUM_CPU_RW_PORTS + sp]);
                    w_memory_resp_ready[M_BOOT][NUM_CPU_RW_PORTS + sp] = w_sys_resp_ready[cl][sp];
                end
            end
        end
    end

    /* ---- */

    for (genvar cl = 0; cl < NUM_CLUSTER; cl++) begin
        always_comb begin
            w_cluster_wake_vec[cl] = '0;
            for (int k = 0; k < CORES_PER_CLUSTER; k++) begin
                w_cluster_wake_vec[cl] = w_cluster_wake_vec[cl] | r_ipi_vector[cl*CORES_PER_CLUSTER + k];
            end
        end
    end

	    for (genvar c = 0; c < NUM_CORES; c++) begin : gen_core_clock_reset
	        localparam int CLUSTER_ID = core_cluster_id(c);
	        localparam int CORE_LOCAL_ID = core_local_id(c);
	        localparam int C_X = cluster_x(CLUSTER_ID);
	        localparam int C_Y = cluster_y(CLUSTER_ID);
            localparam int HOME_MEMORY_ID = cluster_home_memory_id(CLUSTER_ID);
	        assign w_core_clk[c]     = i_clk;
	        assign w_core_rst_n[c]   = rst_cluster_n[CLUSTER_ID];
	        for (genvar t = 0; t < NUM_HW_THRDS; t++) begin
	            assign w_core_wake_intr_vec[c][t] = w_cluster_wake_vec[CLUSTER_ID][t * CORES_PER_CLUSTER + CORE_LOCAL_ID] |
	                (w_sys_intr[CLUSTER_ID] && THRD_W'(w_sys_intr_thrd[CLUSTER_ID]) == THRD_W'(t)) |
	                ((THRD_W'(t * CORES_PER_CLUSTER + CORE_LOCAL_ID) == w_memory_page_completion_thrd[HOME_MEMORY_ID]) ? w_memory_page_completion_pending[HOME_MEMORY_ID] : 1'b0);
	            assign w_core_thrd_id_vec[c][t] = XLEN'(
	                (XLEN'(C_Y) << (THREAD_OFFSET_BITS + MESH_COORD_BITS)) |
	                (XLEN'(C_X) << THREAD_OFFSET_BITS) |
	                XLEN'(t * CORES_PER_CLUSTER + CORE_LOCAL_ID)
	            );
	        end
	    end
    for (genvar m = 0; m < NUM_MEM; m++) begin : gen_memory_clock_reset
        assign w_memory_clk[m]   = i_clk;
        assign w_memory_rst_n[m] = rst_mem_n[m];
    end
    assign w_uart_mmio_clk       = i_clk;
    assign w_uart_mmio_rst_n     = rst_periph_n;
    assign o_uart_tx             = w_uart_mmio_tx;
    assign w_uart_mmio_rx        = i_uart_rx;

	    for (genvar c = 0; c < NUM_CORES; c++) begin
	        assign w_uart_req_valid_vec[c] = w_core_uart_req_valid[c];
    end
    
    always_comb begin
        w_uart_grant = '0;
	        for (int k = 0; k < NUM_CORES; k++) begin
            if (w_uart_req_valid_vec[k]) begin
                w_uart_grant[k] = 1'b1;
                break;
            end
        end
    end

    always_comb begin
        w_uart_mmio_req_valid = 1'b0;
        w_uart_mmio_req_we    = 1'b0;
        w_uart_mmio_req_thrd  = '0;
        w_uart_mmio_req_is_lr = 1'b0;
        w_uart_mmio_req_is_sc = 1'b0;
        w_uart_mmio_req_priv  = '0;
        w_uart_mmio_req_addr  = '0;
        w_uart_mmio_req_wdata = '0;
        w_uart_mmio_req_wstrb = '0;
	        for (int k = 0; k < NUM_CORES; k++) begin
            if (w_uart_grant[k]) begin
                w_uart_mmio_req_valid = 1'b1;
                w_uart_mmio_req_we    = w_router_mmio_req_rw[k];
                w_uart_mmio_req_thrd  = THRD_W'(w_router_mmio_req_thrd_id[k]);
                w_uart_mmio_req_priv  = w_router_mmio_req_priv[k];
                w_uart_mmio_req_addr  = w_router_mmio_req_addr[k];
                w_uart_mmio_req_wdata = w_router_mmio_req_wdata[k] >>
                    (w_router_mmio_req_addr[k][$clog2(XLEN/8)-1:0] * 8);
                w_uart_mmio_req_wstrb = w_router_mmio_req_wstrb[k] >>
                    w_router_mmio_req_addr[k][$clog2(XLEN/8)-1:0];
                break;
            end
        end
    end

    always_comb begin
        w_uart_mmio_resp_ready = 1'b0;
	        for (int k = 0; k < NUM_CORES; k++) begin
            if (r_uart_resp_core == $bits(r_uart_resp_core)'(k)) begin
                w_uart_mmio_resp_ready = w_router_mmio_resp_ready[k];
            end
        end
    end

    for (genvar c = 0; c < NUM_CORES; c++) begin : gen_core_data_resp_mux
        localparam int CORE_CLUSTER_ID = core_cluster_id(c);
        localparam int CORE_LOCAL_ID = core_local_id(c);
        assign w_core_ipi_req_valid[c] = w_router_mmio_req_valid[c] &&
                                         w_router_mmio_req_priv[c] != PRIV_MODE_U &&
                                         is_ipi_addr(w_router_mmio_req_addr[c]);
        assign w_core_oob_req_valid[c] = w_router_mmio_req_valid[c] && is_dummy_oob_data_addr(w_router_mmio_req_addr[c], w_router_mmio_req_priv[c]);
        assign w_core_sys_req_valid[c] = w_router_mmio_req_valid[c] && is_sys_mmio_addr(w_router_mmio_req_addr[c], w_router_mmio_req_priv[c]);
        assign w_core_uart_req_valid[c] = w_router_mmio_req_valid[c] &&
                                          w_router_mmio_req_priv[c] != PRIV_MODE_U &&
                                          w_router_mmio_req_addr[c] >= UART_BASE_ADDR &&
                                          w_router_mmio_req_addr[c] <= UART_END_ADDR;

        always_comb begin
            w_core_timer_resp_rdata_mux[c] = '0;
            w_core_timer_resp_thrd_mux[c] = '0;
            w_core_timer_resp_valid_any[c] = 1'b0;
            for (int t = 0; t < NUM_HW_THRDS; t++) begin
                if (w_core_timer_resp_valid[c][t] && !w_core_timer_resp_valid_any[c]) begin
                    w_core_timer_resp_rdata_mux[c] = w_core_timer_resp_rdata[c][t];
                    w_core_timer_resp_thrd_mux[c] = CORE_THRD_W'(t);
                    w_core_timer_resp_valid_any[c] = 1'b1;
                end
            end
            w_core_timer_req_valid_any[c] = 1'b0;
            for (int t = 0; t < NUM_HW_THRDS; t++) begin
                if (w_router_mmio_req_thrd_id[c] == CORE_THRD_W'(t))
                    w_core_timer_req_valid_any[c] = is_timer_mmio_addr(w_router_mmio_req_addr[c], w_router_mmio_req_priv[c]) &&
                                                    w_router_mmio_req_valid[c] && w_core_timer_req_ready[c][t];
            end
        end

        assign w_router_mmio_req_ready[c] = w_core_uart_req_valid[c] ? (w_uart_grant[c] && w_uart_mmio_req_ready) : w_core_ipi_req_valid[c] ? !r_ipi_resp_valid[c] : w_core_sys_req_valid[c] ? (w_sys_mmio_grant[c] && w_sys_mmio_req_ready[CORE_CLUSTER_ID]) : w_core_oob_req_valid[c] ? !r_oob_resp_valid[c] : w_core_timer_req_valid_any[c];
        assign w_router_mmio_resp_valid[c] = (c == r_uart_resp_core && w_uart_mmio_resp_valid) || (w_sys_mmio_resp_valid[CORE_CLUSTER_ID] && r_sys_resp_core[CORE_CLUSTER_ID] == $bits(r_sys_resp_core[CORE_CLUSTER_ID])'(CORE_LOCAL_ID)) || r_ipi_resp_valid[c] || r_oob_resp_valid[c] || w_core_timer_resp_valid_any[c];
        assign w_router_mmio_resp_rdata[c] = r_ipi_resp_valid[c] ? r_ipi_resp_rdata[c] : r_oob_resp_valid[c] ? '0 : w_core_timer_resp_valid_any[c] ? w_core_timer_resp_rdata_mux[c] : (w_sys_mmio_resp_valid[CORE_CLUSTER_ID] && r_sys_resp_core[CORE_CLUSTER_ID] == $bits(r_sys_resp_core[CORE_CLUSTER_ID])'(CORE_LOCAL_ID)) ? w_sys_mmio_resp_rdata[CORE_CLUSTER_ID] : (c == r_uart_resp_core && w_uart_mmio_resp_valid) ? w_uart_mmio_resp_rdata : '0;
        assign w_router_mmio_resp_sc_ok[c] = (c == r_uart_resp_core && w_uart_mmio_resp_valid) ? w_uart_mmio_resp_sc_succ : 1'b0;
        assign w_router_mmio_resp_thrd_id[c] = r_ipi_resp_valid[c] ? r_ipi_resp_thrd[c] : r_oob_resp_valid[c] ? r_oob_resp_thrd[c] : w_core_timer_resp_valid_any[c] ? w_core_timer_resp_thrd_mux[c] : (w_sys_mmio_resp_valid[CORE_CLUSTER_ID] && r_sys_resp_core[CORE_CLUSTER_ID] == $bits(r_sys_resp_core[CORE_CLUSTER_ID])'(CORE_LOCAL_ID)) ? r_sys_resp_thrd[CORE_CLUSTER_ID] : (c == r_uart_resp_core && w_uart_mmio_resp_valid) ? CORE_THRD_W'(w_uart_mmio_resp_thrd) : '0;
	    end

    always_ff @(posedge i_clk or negedge rst_fabric_n) begin
        if (!rst_fabric_n) begin
            for (int c = 0; c < NUM_CORES; c++) begin
                r_ipi_vector[c]       <= '0;
                r_ipi_resp_valid[c]   <= 1'b0;
                r_ipi_resp_rdata[c]   <= '0;
                r_ipi_resp_thrd[c]    <= '0;
                r_ipi_wake_hold[c]    <= '0;
                r_oob_resp_valid[c]   <= 1'b0;
                r_oob_resp_thrd[c]    <= '0;
                for (int t = 0; t < NUM_HW_THRDS; t++) begin
                    r_core_active_vtid[c][t] <= '0;
                end
            end
            for (int cl = 0; cl < NUM_CLUSTER; cl++) begin
                r_sys_resp_core[cl] <= '0;
                r_sys_resp_thrd[cl] <= '0;
                r_sys_host_thrd[cl] <= '0;
                r_sys_host_vtid[cl] <= '0;
                r_sys_host_vtid_valid[cl] <= 1'b0;
                r_sys_host_priv[cl] <= PRIV_MODE_M;
            end
            r_uart_resp_core          <= '0;
        end else begin
            for (int c = 0; c < NUM_CORES; c++) begin
                if (w_core_page_msg_valid[c] && w_core_page_msg_ready[c]) begin
                    generic_page_msg_t gen_msg;
                    gen_msg = w_core_page_msg[c];
                    if (gen_msg.msg_type == PAGE_MSG_VTID_UPDATE) begin
                        vtid_update_msg_t vtid_msg;
                        vtid_msg = w_core_page_msg[c];
                        r_core_active_vtid[c][core_thread_id(vtid_msg.thrd_id)] <= vtid_msg.vtid;
                    end
                end
                if (r_ipi_resp_valid[c] && w_router_mmio_resp_ready[c]) begin
                    r_ipi_resp_valid[c] <= 1'b0;
                end
                if (r_oob_resp_valid[c] && w_router_mmio_resp_ready[c]) begin
                    r_oob_resp_valid[c] <= 1'b0;
                end
                if (r_ipi_wake_hold[c] != '0) begin
                    r_ipi_wake_hold[c] <= r_ipi_wake_hold[c] - 1'b1;
                    if (r_ipi_wake_hold[c] == 8'd1) begin
                        r_ipi_vector[c] <= '0;
                    end
                end
            end
            for (int k = 0; k < NUM_CORES; k++) begin
	                if (w_uart_grant[k] && w_uart_mmio_req_ready) begin
	                    r_uart_resp_core <= $bits(r_uart_resp_core)'(k);
	                end
	            end
            for (int cl = 0; cl < NUM_CLUSTER; cl++) begin
                int c_x;
                int c_y;
                int m_boot;
                int p_sys;

                c_x = cluster_x(cl);
                c_y = cluster_y(cl);
                m_boot = (c_x % 2 == 0) ? memory_id(c_x + 1, c_y) : memory_id(c_x - 1, c_y);
                p_sys = NUM_CPU_RW_PORTS;

                if (r_sys_host_vtid_valid[cl] && m_boot != -1 &&
                    w_memory_page_msg_ready[m_boot][p_sys]) begin
                    r_sys_host_vtid_valid[cl] <= 1'b0;
                end
                for (int k = 0; k < CORES_PER_CLUSTER; k++) begin
                    int c = cluster_core_id(cl, k);
                    if (w_sys_mmio_grant[c] && w_sys_cmd_host_valid[cl]) begin
                        r_sys_resp_core[cl] <= $bits(r_sys_resp_core[cl])'(k);
                        r_sys_resp_thrd[cl] <= w_router_mmio_req_thrd_id[c];
                        r_sys_host_thrd[cl] <= memory_thread_id(c, w_router_mmio_req_thrd_id[c]);
                        r_sys_host_vtid[cl] <= r_core_active_vtid[c][w_router_mmio_req_thrd_id[c]];
                        r_sys_host_vtid_valid[cl] <= 1'b1;
                        r_sys_host_priv[cl] <= PRIV_MODE_U;
                    end else if (w_sys_mmio_grant[c] && w_sys_mmio_req_ready[cl]) begin
                        r_sys_resp_core[cl] <= $bits(r_sys_resp_core[cl])'(k);
                        r_sys_resp_thrd[cl] <= w_router_mmio_req_thrd_id[c];
                    end
                end
            end
            for (int c = 0; c < NUM_CORES; c++) begin
                if (w_core_oob_req_valid[c] && !r_oob_resp_valid[c]) begin
                    r_oob_resp_valid[c] <= 1'b1;
                    r_oob_resp_thrd[c]  <= w_router_mmio_req_thrd_id[c];
                end
                if (w_core_ipi_req_valid[c] && !r_ipi_resp_valid[c]) begin
                    int ipi_word;
                    ipi_word = ipi_word_index(w_router_mmio_req_addr[c]);
                    r_ipi_resp_valid[c] <= 1'b1;
                    r_ipi_resp_thrd[c] <= w_router_mmio_req_thrd_id[c];
                    if (w_router_mmio_req_rw[c]) begin
                        for (int b = 0; b < THREADS_PER_CLUSTER; b++) begin
                            if ((b / XLEN) == ipi_word) begin
                                /* Accumulate closely spaced targeted wakeups.
                                 * Replacing the whole vector here loses an
                                 * earlier target before a sleeping thread can
                                 * observe it.  The hold counter clears all
                                 * accumulated bits after the wake window. */
                                if (w_router_mmio_req_wdata[c][b % XLEN])
                                    r_ipi_vector[c][b] <= 1'b1;
                            end
                        end
                        r_ipi_wake_hold[c] <= 8'hff;
                        r_ipi_resp_rdata[c] <= '0;
                    end else begin
                        r_ipi_resp_rdata[c] <= '0;
                        for (int b = 0; b < THREADS_PER_CLUSTER; b++) begin
                            if ((b / XLEN) == ipi_word) begin
                                r_ipi_resp_rdata[c][b % XLEN] <= r_ipi_vector[c][b];
                            end
                        end
                    end
                end
            end
        end
    end
    /* ---- */

    for (genvar m = 1; m < NUM_MEM; m++) begin : gen_unused_page_engine_if
        assign w_memory_page_req_ready [m] = 1'b0;
        assign w_memory_page_resp_addr  [m] = '0;
        assign w_memory_page_resp_we    [m] = 1'b0;
        assign w_memory_page_resp_wdata [m] = '0;
        assign w_memory_page_resp_valid [m] = 1'b0;
        assign w_memory_page_transfer_done[m] = 1'b0;
    end

endmodule: soc
