/* SPDX-License-Identifier: Apache-2.0 */
`include "uvm_macros.svh"
import uvm_pkg::*;
module sys_core_tb_top;
 sys_core_if vif();
 sys_core dut(.i_clk(vif.clk),.i_rst_n(vif.rst_n),.i_mmio_req_valid(vif.mmio_req_valid),.i_mmio_req_addr(vif.mmio_req_addr),.i_mmio_req_wdata(vif.mmio_req_wdata),.i_mmio_req_wmask(vif.mmio_req_wmask),.o_mmio_req_ready(vif.mmio_req_ready),.o_mmio_resp_valid(vif.mmio_resp_valid),.o_mmio_resp_rdata(vif.mmio_resp_rdata),.i_mmio_resp_ready(vif.mmio_resp_ready),.i_host_thrd(vif.host_thrd),.o_intr(vif.intr),.o_intr_thrd(vif.intr_thrd),.o_req_we(vif.req_we),.o_req_thrd(vif.req_thrd),.o_req_is_lr(vif.req_is_lr),.o_req_is_sc(vif.req_is_sc),.o_req_addr(vif.req_addr),.o_req_wstrb(vif.req_wstrb),.o_req_wdata(vif.req_wdata),.o_req_valid(vif.req_valid),.i_req_ready(vif.req_ready),.i_resp_thrd(vif.resp_thrd),.i_resp_sc_succ(vif.resp_sc_succ),.i_resp_rdata(vif.resp_rdata),.i_resp_valid(vif.resp_valid),.o_resp_ready(vif.resp_ready));
 initial begin uvm_config_db#(virtual sys_core_if)::set(null,"*","vif",vif);run_test();end
 initial begin vif.clk=0;vif.rst_n=0;vif.mmio_req_valid=0;vif.mmio_req_addr=0;vif.mmio_req_wdata=0;vif.mmio_req_wmask=0;vif.mmio_resp_ready=0;vif.host_thrd=0;for(int p=0;p<3;p++)begin vif.req_ready[p]=1;vif.resp_thrd[p]=0;vif.resp_sc_succ[p]=0;vif.resp_rdata[p]=0;vif.resp_valid[p]=0;end repeat(5)@(posedge vif.clk);vif.rst_n=1;$dumpfile("sys_core_tb.vcd");$dumpvars(0,sys_core_tb_top);end
 always #5ns vif.clk=~vif.clk;
endmodule: sys_core_tb_top

