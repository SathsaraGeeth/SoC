/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
`include "uvm_macros.svh"
import uvm_pkg::*;
module sys_address_generator_tb_top;
    sys_address_generator_if vif();
    for (genvar kind = 0; kind < 3; kind++) begin: gen_dut
        sys_address_generator #(.IS_WB(kind == 2), .IS_B(kind == 1)) dut (
            .i_clk(vif.clk), .i_rst_n(vif.rst_n), .i_start(vif.start[kind]),
            .i_tid(vif.tid[kind]), .i_base_addr(vif.base_addr[kind]),
            .i_a_tiles(vif.a_tiles[kind]), .i_b_tiles(vif.b_tiles[kind]),
            .i_dense(vif.dense[kind]), .i_cmd_start(vif.cmd_start[kind]),
            .i_cmd_last(vif.cmd_last[kind]), .i_mac_type(vif.mac_type[kind]),
            .i_addr_enq_ready(vif.ready[kind]), .o_addr_enq_valid(vif.valid[kind]),
            .o_addr_enq_data(vif.data[kind]), .o_done(vif.done[kind])
        );
    end
    initial begin uvm_config_db#(virtual sys_address_generator_if)::set(null, "*", "vif", vif); run_test(); end
    initial begin
        vif.clk = 0; vif.rst_n = 0; vif.start = 0; vif.ready = '1; vif.dense = 0; vif.cmd_start = 0; vif.cmd_last = 0;
        for (int kind = 0; kind < 3; kind++) begin vif.tid[kind] = 0; vif.base_addr[kind] = 0; vif.a_tiles[kind] = 1; vif.b_tiles[kind] = 1; vif.mac_type[kind] = sys_cnfg_pkg::MAC20I; end
        repeat (4) @(posedge vif.clk); vif.rst_n = 1; $dumpfile("sys_address_generator_tb.vcd"); $dumpvars(0, sys_address_generator_tb_top);
    end
    always #5ns vif.clk = ~vif.clk;
endmodule: sys_address_generator_tb_top
