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

module fpu_tb_top;
    fpu_if vif();

    fpu dut (
        .i_clk          (vif.clk),
        .i_rst_n        (vif.rst_n),
        .i_issued_instr (vif.issued_instr),
        .o_req_ready    (vif.req_ready),
        .i_req_valid    (vif.req_valid),
        .o_res_thrd_id  (vif.res_thrd_id),
        .o_res_valid    (vif.res_valid),
        .i_res_ready    (vif.res_ready),
        .o_result       (vif.result)
    );

    initial begin
        uvm_config_db#(virtual fpu_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk          = 1'b0;
        vif.rst_n        = 1'b0;
        vif.issued_instr = '0;
        vif.req_valid    = 1'b0;
        vif.res_ready    = 1'b0;
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("fpu_tb.vcd");
        $dumpvars(0, fpu_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: fpu_tb_top

