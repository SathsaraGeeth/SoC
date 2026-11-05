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

module sram_bank_tb_top;
    sram_bank_if vif();

    sram_bank #(.BANK_IDX(0)) dut (
        .i_clk          (vif.clk),
        .i_rst_n        (vif.rst_n),
        .i_req_valid    (vif.req_valid),
        .i_resp_expected(vif.resp_expected),
        .o_req_ready    (vif.req_ready),
        .o_resp_valid   (vif.resp_valid),
        .i_resp_ready   (vif.resp_ready),
        .i_req_port     (vif.req_port),
        .i_req_thrd     (vif.req_thrd),
        .i_lr           (vif.lr),
        .i_sc           (vif.sc),
        .i_raddr        (vif.raddr),
        .i_waddr        (vif.waddr),
        .i_wstrb        (vif.wstrb),
        .i_wdata        (vif.wdata),
        .i_we           (vif.we),
        .o_sc_succ      (vif.sc_succ),
        .o_resp_port    (vif.resp_port),
        .o_resp_thrd    (vif.resp_thrd),
        .o_rdata        (vif.rdata)
    );

    initial begin
        uvm_config_db#(virtual sram_bank_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk = 1'b0;
        vif.rst_n = 1'b0;
        vif.req_valid = 1'b0;
        vif.resp_expected = 1'b1;
        vif.resp_ready = 1'b1;
        vif.req_port = '0;
        vif.req_thrd = '0;
        vif.lr = 1'b0;
        vif.sc = 1'b0;
        vif.raddr = '0;
        vif.waddr = '0;
        vif.wstrb = '0;
        vif.wdata = '0;
        vif.we = 1'b0;
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("sram_bank_tb.vcd");
        $dumpvars(0, sram_bank_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: sram_bank_tb_top

