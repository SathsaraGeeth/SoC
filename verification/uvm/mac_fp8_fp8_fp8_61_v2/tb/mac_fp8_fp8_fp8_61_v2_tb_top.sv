/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
`include "uvm_macros.svh"
import uvm_pkg::*;
module mac_fp8_fp8_fp8_61_v2_tb_top;
    mac_fp8_fp8_fp8_61_v2_if vif();
    mac_fp8_fp8_fp8_61_v2 dut(.i_clk(vif.clk),.i_rst_n(vif.rst_n),.i_en(vif.en),.i_clr_n(vif.clr_n),.i_start(vif.start),.i_last(vif.last),.o_done(vif.done),.i_a(vif.a),.i_b(vif.b),.o_d(vif.d));
    initial begin uvm_config_db#(virtual mac_fp8_fp8_fp8_61_v2_if)::set(null,"*","vif",vif);run_test();end
    initial begin vif.clk=0;vif.rst_n=0;vif.en=1;vif.clr_n=1;vif.start=0;vif.last=0;vif.a=0;vif.b=0;repeat(4)@(posedge vif.clk);vif.rst_n=1;$dumpfile("mac_fp8_fp8_fp8_61_v2_tb.vcd");$dumpvars(0,mac_fp8_fp8_fp8_61_v2_tb_top);end
    always #5ns vif.clk=~vif.clk;
endmodule: mac_fp8_fp8_fp8_61_v2_tb_top
