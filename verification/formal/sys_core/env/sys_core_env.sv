`default_nettype none
module sys_core_formal(
 input logic clk,input logic rst_n,input logic req_valid,input logic[63:0]req_addr,
 input logic[63:0]req_wdata,input logic[7:0]req_wmask,input logic resp_ready,
 input logic[memory_pkg::THRD_W-1:0]host_thrd);
 logic req_ready,resp_valid,intr;logic[63:0]resp_rdata,intr_thrd;logic f_past_valid=0;
 logic req_we[2:0],req_is_lr[2:0],req_is_sc[2:0],mem_req_valid[2:0],mem_req_ready[2:0];
 logic[63:0]req_thrd_o[2:0],mem_req_addr[2:0],mem_req_wdata[2:0],mem_resp_thrd[2:0],mem_resp_rdata[2:0];
 logic[7:0]mem_req_wstrb[2:0];logic mem_resp_sc[2:0],mem_resp_valid[2:0],mem_resp_ready[2:0];
 always_comb for(int p=0;p<3;p++)begin mem_req_ready[p]=1'b0;mem_resp_thrd[p]='0;mem_resp_rdata[p]='0;mem_resp_sc[p]=0;mem_resp_valid[p]=0;end
 sys_core dut(.i_clk(clk),.i_rst_n(rst_n),.i_mmio_req_valid(req_valid),.i_mmio_req_addr(req_addr),.i_mmio_req_wdata(req_wdata),.i_mmio_req_wmask(req_wmask),.o_mmio_req_ready(req_ready),.o_mmio_resp_valid(resp_valid),.o_mmio_resp_rdata(resp_rdata),.i_mmio_resp_ready(resp_ready),.i_host_thrd(host_thrd),.o_intr(intr),.o_intr_thrd(intr_thrd),.o_req_we(req_we),.o_req_thrd(req_thrd_o),.o_req_is_lr(req_is_lr),.o_req_is_sc(req_is_sc),.o_req_addr(mem_req_addr),.o_req_wstrb(mem_req_wstrb),.o_req_wdata(mem_req_wdata),.o_req_valid(mem_req_valid),.i_req_ready(mem_req_ready),.i_resp_thrd(mem_resp_thrd),.i_resp_sc_succ(mem_resp_sc),.i_resp_rdata(mem_resp_rdata),.i_resp_valid(mem_resp_valid),.o_resp_ready(mem_resp_ready));
 always_ff@(posedge clk)f_past_valid<=1;
 `include "sys_core_assumptions.sv"
 `include "sys_core_reset.sv"
 `include "sys_core_protocol.sv"
 `include "sys_core_coverpoints.sv"
endmodule
`default_nettype wire

