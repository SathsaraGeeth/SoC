/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

typedef enum int unsigned {
    ROUTER_INSTR,
    ROUTER_DATA,
    ROUTER_PAGE_OUT,
    ROUTER_PAGE_INSTR,
    ROUTER_PAGE_DATA
} router_kind_e;

class router_txn extends uvm_sequence_item;
    rand router_kind_e kind;
    rand bit [2:0] direction;
    rand bit [1:0] priv;
    rand bit [topology_pkg::VIR_ADDR_W-1:0] addr;
    rand bit [$clog2(core_pkg::NUM_HW_THRDS)-1:0] thrd;
    rand bit rw;
    rand bit lq;
    rand bit sc;
    rand bit [core_pkg::XLEN/8-1:0] wstrb;
    rand bit [core_pkg::XLEN-1:0] wdata;
    rand bit [memory_pkg::PAGE_MSG_W-1:0] page_msg;
    rand int unsigned stall_cycles;
    rand bit all_sources;
    bit [core_pkg::XLEN-1:0] resp_data;
    bit resp_sc_ok;
    bit [$clog2(core_pkg::NUM_HW_THRDS)-1:0] resp_thrd;
    bit [3:0] route_mask;

    constraint c_legal {
        direction <= 4;
        priv inside {isa_pkg::PRIV_MODE_U, isa_pkg::PRIV_MODE_M};
        stall_cycles inside {[0:3]};
    }

    `uvm_object_utils_begin(router_txn)
        `uvm_field_enum(router_kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(direction, UVM_ALL_ON)
        `uvm_field_int(priv, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(thrd, UVM_ALL_ON)
        `uvm_field_int(rw, UVM_ALL_ON)
        `uvm_field_int(lq, UVM_ALL_ON)
        `uvm_field_int(sc, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(page_msg, UVM_ALL_ON)
        `uvm_field_int(stall_cycles, UVM_ALL_ON)
        `uvm_field_int(all_sources, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "router_txn");
        super.new(name);
    endfunction
endclass: router_txn
