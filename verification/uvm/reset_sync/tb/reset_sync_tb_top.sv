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

module reset_sync_tb_top;
    reset_sync_if vif();

    reset_sync #(
        .STAGES (2)
    ) dut (
        .i_clk         (vif.clk),
        .i_async_rst_n (vif.async_rst_n),
        .o_rst_n       (vif.rst_n)
    );

    initial begin
        uvm_config_db#(virtual reset_sync_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk         = 1'b0;
        vif.async_rst_n = 1'b0;
        $dumpfile("reset_sync_tb.vcd");
        $dumpvars(0, reset_sync_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: reset_sync_tb_top

