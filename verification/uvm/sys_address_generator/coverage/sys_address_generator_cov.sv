/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_cov extends uvm_subscriber #(sys_address_generator_txn);
    `uvm_component_utils(sys_address_generator_cov)
    bit [1:0] kind; bit dense;
    covergroup addr_cg; cp_kind: coverpoint kind { bins variants[] = {[0:2]}; } cp_dense: coverpoint dense; variant_x_dense: cross cp_kind, cp_dense; endgroup
    function new(string name = "sys_address_generator_cov", uvm_component parent = null); super.new(name, parent); addr_cg = new(); endfunction
    function void write(sys_address_generator_txn txn); kind = txn.kind; dense = txn.dense; addr_cg.sample(); endfunction
endclass: sys_address_generator_cov
