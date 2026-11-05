/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
import sys_cnfg_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_txn extends uvm_sequence_item;
    localparam int DATA_W = VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+2;
    rand bit [1:0] kind;
    rand bit [1:0] a_tiles;
    rand bit [1:0] b_tiles;
    rand bit dense;
    rand bit cmd_start;
    rand bit cmd_last;
    rand mac_t mac_type;
    rand bit [XLEN-1:0] tid;
    rand bit [VIR_ADDR_W-1:0] base_addr;
    bit [DATA_W-1:0] data;
    constraint c_legal { kind < 3; a_tiles inside {[1:3]}; b_tiles inside {[1:3]}; base_addr[5:0] == '0; }
    `uvm_object_utils_begin(sys_address_generator_txn)
        `uvm_field_int(kind, UVM_ALL_ON)
        `uvm_field_int(a_tiles, UVM_ALL_ON)
        `uvm_field_int(b_tiles, UVM_ALL_ON)
        `uvm_field_int(dense, UVM_ALL_ON)
        `uvm_field_int(cmd_start, UVM_ALL_ON)
        `uvm_field_int(cmd_last, UVM_ALL_ON)
        `uvm_field_enum(mac_t, mac_type, UVM_ALL_ON)
        `uvm_field_int(tid, UVM_ALL_ON)
        `uvm_field_int(base_addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name = "sys_address_generator_txn"); super.new(name); endfunction
endclass: sys_address_generator_txn
