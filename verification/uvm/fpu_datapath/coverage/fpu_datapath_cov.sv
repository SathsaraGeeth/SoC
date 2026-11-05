/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
import fpu_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_cov extends uvm_subscriber #(fpu_datapath_txn);
    `uvm_component_utils(fpu_datapath_cov)

    bit lane;
    fp_op_e op;
    covergroup datapath_cg;
        cp_lane: coverpoint lane;
        cp_op: coverpoint op {
            bins arithmetic[] = {ADD, SUB, MUL, FMA};
        }
        lane_x_op: cross cp_lane, cp_op;
    endgroup

    function new(string name = "fpu_datapath_cov", uvm_component parent = null);
        super.new(name, parent);
        datapath_cg = new();
    endfunction

    function void write(fpu_datapath_txn txn);
        lane = txn.lane;
        op   = txn.op;
        datapath_cg.sample();
    endfunction
endclass: fpu_datapath_cov
