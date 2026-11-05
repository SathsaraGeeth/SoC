/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_txn extends uvm_sequence_item;
    rand bit [7:0] offset; rand bit [63:0] data; rand bit [7:0] mask;
    rand bit [2:0] host; rand int unsigned backpressure; rand int unsigned idle_cycles;
    bit response; bit [63:0] rdata;
    constraint c_req {offset inside {8'h00,8'h08,8'h10,8'h18}; backpressure inside {[0:3]}; idle_cycles inside {[0:2]};}
    `uvm_object_utils_begin(sys_core_txn)
      `uvm_field_int(offset,UVM_ALL_ON) `uvm_field_int(data,UVM_ALL_ON)
      `uvm_field_int(mask,UVM_ALL_ON) `uvm_field_int(host,UVM_ALL_ON)
      `uvm_field_int(backpressure,UVM_ALL_ON) `uvm_field_int(idle_cycles,UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="sys_core_txn");super.new(name);endfunction
endclass: sys_core_txn

