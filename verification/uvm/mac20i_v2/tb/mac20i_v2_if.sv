/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
interface mac20i_v2_if;
    logic clk, rst_n, en, clr_n, start, last, done;
    logic [7:0] a, b, d;
endinterface: mac20i_v2_if
