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

module regfile_tb_top;
    regfile_if vif();

    regfile dut (
        .i_clk       (vif.clk),
        .i_we        (vif.we),
        .i_rs1_addr  (vif.rs1_addr),
        .i_rs2_addr  (vif.rs2_addr),
        .i_rs3_addr  (vif.rs3_addr),
        .i_rthrd_id  (vif.rthrd_id),
        .i_rd_addr   (vif.rd_addr),
        .i_wthrd_id  (vif.wthrd_id),
        .i_rd_wdata  (vif.rd_wdata),
        .o_rs1_data  (vif.rs1_data),
        .o_rs2_data  (vif.rs2_data),
        .o_rs3_data  (vif.rs3_data)
    );

    initial begin
        uvm_config_db#(virtual regfile_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk       = 1'b0;
        vif.we        = 1'b0;
        vif.rs1_addr  = '0;
        vif.rs2_addr  = '0;
        vif.rs3_addr  = '0;
        vif.rthrd_id  = '0;
        vif.rd_addr   = '0;
        vif.wthrd_id  = '0;
        vif.rd_wdata  = '0;
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, regfile_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: regfile_tb_top

