/* SPDX-License-Identifier: Apache-2.0 */
interface sys_core_if;
    logic clk,rst_n,mmio_req_valid,mmio_req_ready,mmio_resp_valid,mmio_resp_ready;
    logic [63:0] mmio_req_addr,mmio_req_wdata,mmio_resp_rdata;
    logic [7:0] mmio_req_wmask;
    logic [2:0] host_thrd;
    logic intr; logic [63:0] intr_thrd;
    logic req_we[2:0],req_is_lr[2:0],req_is_sc[2:0],req_valid[2:0],req_ready[2:0];
    logic [63:0] req_thrd[2:0],req_addr[2:0],req_wdata[2:0],resp_thrd[2:0],resp_rdata[2:0];
    logic [7:0] req_wstrb[2:0]; logic resp_sc_succ[2:0],resp_valid[2:0],resp_ready[2:0];
endinterface: sys_core_if

