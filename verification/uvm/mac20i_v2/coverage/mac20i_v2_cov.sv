/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac20i_v2_cov extends uvm_subscriber #(mac20i_v2_txn);
    `uvm_component_utils(mac20i_v2_cov)
    bit [1:0] terms; bit a_sign, b_sign;
    covergroup mac_cg; cp_terms: coverpoint terms { bins term_count[] = {[1:3]}; } cp_a_sign: coverpoint a_sign; cp_b_sign: coverpoint b_sign; signs: cross cp_a_sign, cp_b_sign; endgroup
    function new(string name = "mac20i_v2_cov", uvm_component parent = null); super.new(name, parent); mac_cg = new(); endfunction
    function void write(mac20i_v2_txn txn); terms = txn.terms; a_sign = txn.a[0][7]; b_sign = txn.b[0][7]; mac_cg.sample(); endfunction
endclass: mac20i_v2_cov
