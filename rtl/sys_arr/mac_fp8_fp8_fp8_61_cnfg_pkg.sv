/*
 * mac_fp8_fp8_fp8_61_cnfg_pkg.sv
 * 
 * Copyright (C) 2025 Sathsara Geeth
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

`timescale 1ns/1ps
`default_nettype none

package mac_fp8_fp8_fp8_61_cnfg_pkg;
    import sys_cnfg_pkg::*;
    // fp8 e4m3
    localparam MAN_BITS      = 3;
    localparam EXP_BIAS      = 7;
    localparam EXP_MAX       = 14;
    // design param
    parameter  INTL_W        = 32;
    parameter  MAX_ACCS      = 8;   /* do not fucking change from 8 */
    // acc headroom
    localparam GUARD         = 15;
    localparam SHIFT_ADJ     = 13;
    localparam ACC_HEADROOM  = $clog2(MAX_ACCS) + GUARD;
    localparam REF_BIT       = INTL_W - 1 - ACC_HEADROOM;          // where impl.1 lands
    // noramalized bit vec
    localparam MAN_B2        = INTL_W - 2;                         // mantissa msb
    localparam MAN_B1        = INTL_W - 3;                         // mantissa bit 1
    localparam MAN_B0        = INTL_W - 4;                         // mantissa lsb
    localparam G_BIT         = INTL_W - 5;                         // guard bit
    localparam R_BIT         = INTL_W - 6;                         // round bit
    localparam STICKY_LSB    = INTL_W - 7;                         // sticky lsb
    // algn and exp recovery
    localparam PROD_MSB      = MAN_BITS + MAN_BITS;                // impl.1 pos in 8-bit prod
    localparam SHIFT_OFFSET  = REF_BIT - SHIFT_ADJ;
    localparam EXP_MAP_CONST = SHIFT_OFFSET + PROD_MSB;            // lza thresh for exp=1
endpackage: mac_fp8_fp8_fp8_61_cnfg_pkg
