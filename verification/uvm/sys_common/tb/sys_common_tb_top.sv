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

module sys_common_tb_top;
    sys_common_if vif();

    register #(.WIDTH(8)) u_register(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_clr_n(vif.clr_n),
        .i_en(vif.en), .i_data(vif.data0), .o_data(vif.reg_out));
    mux2 #(.WIDTH(8)) u_mux(
        .i_sel(vif.sel), .i_data0(vif.data0), .i_data1(vif.data1),
        .o_data(vif.mux_out));
    delayed_pipe #(.WIDTH(8), .DEPTH(2)) u_pipe(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_en(vif.en),
        .i_clr_n(vif.clr_n), .i_in(vif.data0), .o_out(vif.pipe_out));
    mul_lat1 #(.IN_WIDTH(8)) u_mul(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_clr_n(vif.clr_n),
        .i_en(vif.en), .i_data0(vif.data0), .i_data1(vif.data1),
        .o_data(vif.mul_out));
    add_lat1 #(.IN_WIDTH(8)) u_add(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_clr_n(vif.clr_n),
        .i_en(vif.en), .i_data0(vif.data0), .i_data1(vif.data1),
        .o_data(vif.add_out));
    delayed_pipev #(.WIDTH(8), .DEPTH(4), .M(4)) u_pipev(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_en(vif.en),
        .i_clr_n(vif.clr_n), .i_in(vif.data0), .i_ptr(vif.ptr),
        .o_out(vif.pipev_out));
    ctr #(.WIDTH(8)) u_ctr(
        .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_start(vif.start),
        .i_en(vif.en), .i_target(vif.target), .o_done(vif.done));

    initial begin
        uvm_config_db#(virtual sys_common_if)::set(null, "*", "vif", vif);
        run_test();
    end
    initial begin
        vif.clk = 1'b0; vif.rst_n = 1'b0; vif.en = 1'b0;
        vif.clr_n = 1'b1; vif.start = 1'b0; vif.sel = 1'b0;
        vif.data0 = '0; vif.data1 = '0; vif.ptr = '0; vif.target = '0;
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("sys_common_tb.vcd");
        $dumpvars(0, sys_common_tb_top);
    end
    always #5ns vif.clk = ~vif.clk;
endmodule: sys_common_tb_top

