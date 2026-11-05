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

module circular_buffer_tb_top;
    localparam int DEPTH = 8;
    localparam int WIDTH = 8;

    circular_buffer_if vif();

    circular_buffer #(
        .DEPTH (DEPTH),
        .WIDTH (WIDTH)
    ) dut (
        .i_clk           (vif.clk),
        .i_rst_n         (vif.rst_n),
        .o_head_data     (vif.head_data),
        .o_deq_ready     (vif.deq_ready),
        .i_deq_valid     (vif.deq_valid),
        .i_enq_tail_data (vif.enq_tail_data),
        .i_enq_valid     (vif.enq_valid),
        .o_enq_ready     (vif.enq_ready),
        .o_full          (vif.full),
        .o_empty         (vif.empty),
        .o_level         (vif.level),
        .i_clr_n         (vif.clr_n)
    );

    initial begin
        uvm_config_db#(virtual circular_buffer_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk           = 1'b0;
        vif.rst_n         = 1'b0;
        vif.clr_n         = 1'b1;
        vif.enq_valid     = 1'b0;
        vif.deq_valid     = 1'b0;
        vif.enq_tail_data = '0;
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("circular_buffer_tb.vcd");
        $dumpvars(0, circular_buffer_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: circular_buffer_tb_top
