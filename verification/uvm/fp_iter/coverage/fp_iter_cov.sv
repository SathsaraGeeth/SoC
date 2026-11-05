/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_cov extends uvm_subscriber #(fp_iter_txn);
    `uvm_component_utils(fp_iter_cov)

    bit [1:0] kind;
    covergroup iter_cg;
        cp_kind: coverpoint kind {
            bins bypass_lane0 = {0};
            bins bypass_lane1 = {1};
            bins div_zero     = {2};
            bins sqrt_neg     = {3};
        }
    endgroup

    function new(string name = "fp_iter_cov", uvm_component parent = null);
        super.new(name, parent);
        iter_cg = new();
    endfunction

    function void write(fp_iter_txn txn);
        kind = txn.kind;
        iter_cg.sample();
    endfunction
endclass: fp_iter_cov
