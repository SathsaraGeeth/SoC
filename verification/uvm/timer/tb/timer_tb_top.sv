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

module timer_tb_top;
    timer_if vif();

    timer dut (
        .clk_i        (vif.clk),
        .rst_ni       (vif.rst_n),
        .req_valid_i  (vif.req_valid),
        .req_addr_i   (vif.req_addr),
        .req_we_i     (vif.req_we),
        .req_wstrb_i  (vif.req_wstrb),
        .req_wdata_i  (vif.req_wdata),
        .req_ready_o  (vif.req_ready),
        .resp_valid_o (vif.resp_valid),
        .resp_ready_i (vif.resp_ready),
        .resp_rdata_o (vif.resp_rdata),
        .irq_timer_o  (vif.irq_timer)
    );

    initial begin
        uvm_config_db#(virtual timer_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk        = 1'b0;
        vif.rst_n      = 1'b0;
        vif.req_valid  = 1'b0;
        vif.req_addr   = '0;
        vif.req_we     = 1'b0;
        vif.req_wstrb  = '0;
        vif.req_wdata  = '0;
        vif.resp_ready = 1'b0;
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("timer_tb.vcd");
        $dumpvars(0, timer_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: timer_tb_top

