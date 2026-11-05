/* SPDX-License-Identifier: Apache-2.0 */
`include "uvm_macros.svh"
import uvm_pkg::*;
module mmacu_core_v2_tb_top;
    mmacu_core_v2_if vif();
    mmacu_core_v2 #(.MAC_STATIC_TYPE(sys_cnfg_pkg::MAC20I_STATIC)) dut(
        .i_clk(vif.clk),.i_rst_n(vif.rst_n),.i_dense(vif.dense),.i_mac_type(sys_cnfg_pkg::MAC20I),
        .i_k2(vif.k2),.i_start(vif.start),.i_last(vif.last),.i_end(vif.end_tile),
        .i_a(vif.a),.i_b(vif.b),.i_a_valid(vif.a_valid),.i_b_valid(vif.b_valid),
        .o_a_ready(vif.a_ready),.o_b_ready(vif.b_ready),.o_d(vif.d),.o_d_valid(vif.d_valid),.i_d_ready(vif.d_ready));
    initial begin uvm_config_db#(virtual mmacu_core_v2_if)::set(null,"*","vif",vif);run_test();end
    initial begin vif.clk=0;vif.rst_n=0;vif.dense=0;vif.mac_type=0;vif.k2=1;vif.start=0;vif.last=0;vif.end_tile=0;vif.a=0;vif.b=0;vif.a_valid=0;vif.b_valid=0;vif.d_ready=0;repeat(5)@(posedge vif.clk);vif.rst_n=1;$dumpfile("mmacu_core_v2_tb.vcd");$dumpvars(0,mmacu_core_v2_tb_top);end
    always #5ns vif.clk=~vif.clk;
endmodule: mmacu_core_v2_tb_top
