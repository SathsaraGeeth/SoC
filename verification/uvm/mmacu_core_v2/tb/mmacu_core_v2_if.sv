/* SPDX-License-Identifier: Apache-2.0 */
interface mmacu_core_v2_if;
    logic clk, rst_n, dense;
    logic [1:0] mac_type;
    logic [5:0] k2;
    logic start, last, end_tile;
    logic [63:0] a, b;
    logic a_valid, b_valid, a_ready, b_ready;
    logic [63:0] d;
    logic d_valid, d_ready;
endinterface: mmacu_core_v2_if

