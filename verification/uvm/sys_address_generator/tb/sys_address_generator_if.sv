/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
interface sys_address_generator_if;
    import sys_cnfg_pkg::*;
    localparam int DATA_W = VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+2;
    logic clk, rst_n;
    logic [2:0] start;
    logic [XLEN-1:0] tid [3];
    logic [VIR_ADDR_W-1:0] base_addr [3];
    logic [TILE_W-1:0] a_tiles [3];
    logic [TILE_W-1:0] b_tiles [3];
    logic [2:0] dense, cmd_start, cmd_last;
    mac_t mac_type [3];
    logic [2:0] ready, valid, done;
    logic [DATA_W-1:0] data [3];
endinterface: sys_address_generator_if
