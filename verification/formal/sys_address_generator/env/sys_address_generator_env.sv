`default_nettype none
import sys_cnfg_pkg::*;
module sys_address_generator_formal (
    input logic clk, input logic rst_n, input logic start,
    input logic [XLEN-1:0] tid,
    input logic [VIR_ADDR_W-1:0] base_addr,
    input logic [TILE_W-1:0] a_tiles,
    input logic [TILE_W-1:0] b_tiles,
    input logic dense, input logic cmd_start, input logic cmd_last,
    input mac_t mac_type, input logic addr_ready
);
    logic addr_valid, done;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] addr_data;
    logic f_past_valid = 1'b0;
    sys_address_generator dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_start(start), .i_tid(tid),
        .i_base_addr(base_addr), .i_a_tiles(a_tiles), .i_b_tiles(b_tiles),
        .i_dense(dense), .i_cmd_start(cmd_start), .i_cmd_last(cmd_last),
        .i_mac_type(mac_type), .i_addr_enq_ready(addr_ready),
        .o_addr_enq_valid(addr_valid), .o_addr_enq_data(addr_data), .o_done(done)
    );
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    `include "sys_address_generator_assumptions.sv"
    `include "sys_address_generator_reset.sv"
    `include "sys_address_generator_protocol.sv"
    `include "sys_address_generator_first.sv"
    `include "sys_address_generator_coverpoints.sv"
endmodule: sys_address_generator_formal
`default_nettype wire
