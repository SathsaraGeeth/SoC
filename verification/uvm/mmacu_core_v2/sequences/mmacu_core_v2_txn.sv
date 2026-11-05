/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mmacu_core_v2_txn extends uvm_sequence_item;
    rand bit signed [7:0] a[8];
    rand bit signed [7:0] b[8];
    rand int unsigned output_stall;
    bit output_event;
    bit start, end_tile;
    bit [63:0] d;
    constraint c_data { foreach (a[i]) a[i] inside {[-4:4]};
                        foreach (b[i]) b[i] inside {[-4:4]};
                        output_stall inside {[0:3]}; }
    `uvm_object_utils_begin(mmacu_core_v2_txn)
        `uvm_field_sarray_int(a, UVM_ALL_ON)
        `uvm_field_sarray_int(b, UVM_ALL_ON)
        `uvm_field_int(output_stall, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="mmacu_core_v2_txn"); super.new(name); endfunction
endclass: mmacu_core_v2_txn

