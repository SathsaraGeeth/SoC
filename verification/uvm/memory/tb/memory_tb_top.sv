/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

`include "uvm_macros.svh"
import uvm_pkg::*;

module memory_tb_top;
    memory_if vif();

    memory #(.REGION_ID(0)) dut (
        .i_clk(vif.clk), .i_rst_n(vif.rst_n),
        .i_req_we(vif.req_we), .i_req_thrd(vif.req_thrd),
        .i_req_is_lr(vif.req_is_lr), .i_req_is_sc(vif.req_is_sc),
        .i_req_addr(vif.req_addr), .i_req_wstrb(vif.req_wstrb),
        .i_req_wdata(vif.req_wdata), .i_req_valid(vif.req_valid),
        .i_req_priv(vif.req_priv), .o_req_ready(vif.req_ready),
        .o_resp_thrd(vif.resp_thrd), .o_resp_sc_succ(vif.resp_sc_succ),
        .o_resp_rdata(vif.resp_rdata), .o_resp_valid(vif.resp_valid),
        .i_resp_ready(vif.resp_ready),
        .i_page_msg_valid(vif.page_msg_valid),
        .o_page_msg_ready(vif.page_msg_ready),
        .i_page_msg(vif.page_msg_in),
        .i_page_msg_ready(vif.page_msg_out_ready),
        .o_page_msg_valid(vif.page_msg_out_valid),
        .o_page_msg(vif.page_msg_out),
        .o_page_req_we(vif.page_req_we),
        .o_page_req_valid(vif.page_req_valid),
        .i_page_req_ready(vif.page_req_ready),
        .o_page_req_addr(vif.page_req_addr),
        .o_page_req_wdata(vif.page_req_wdata),
        .i_page_resp_addr(vif.page_resp_addr),
        .i_page_resp_we(vif.page_resp_we),
        .i_page_resp_wdata(vif.page_resp_wdata),
        .i_page_resp_valid(vif.page_resp_valid),
        .o_page_resp_ready(vif.page_resp_ready),
        .i_page_transfer_done(vif.page_transfer_done),
        .o_page_completion_pending(vif.page_completion_pending),
        .o_page_completion_thrd(vif.page_completion_thrd)
    );

    initial begin
        uvm_config_db#(virtual memory_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk = 1'b0;
        vif.rst_n = 1'b0;
        vif.page_req_ready = 1'b1;
        vif.page_resp_addr = '0;
        vif.page_resp_we = 1'b0;
        vif.page_resp_wdata = '0;
        vif.page_resp_valid = 1'b0;
        vif.page_transfer_done = 1'b0;
        for (int p = 0; p < memory_pkg::NUM_RW_PORTS; p++) begin
            vif.req_we[p] = 1'b0;
            vif.req_thrd[p] = '0;
            vif.req_is_lr[p] = 1'b0;
            vif.req_is_sc[p] = 1'b0;
            vif.req_addr[p] = '0;
            vif.req_wstrb[p] = '0;
            vif.req_wdata[p] = '0;
            vif.req_valid[p] = 1'b0;
            vif.req_priv[p] = isa_pkg::PRIV_MODE_M;
            vif.resp_ready[p] = 1'b1;
            vif.page_msg_valid[p] = 1'b0;
            vif.page_msg_in[p] = '0;
            vif.page_msg_out_ready[p] = 1'b1;
        end
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("memory_tb.vcd");
        $dumpvars(0, memory_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: memory_tb_top

