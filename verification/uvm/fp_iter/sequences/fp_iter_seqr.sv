/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_seqr extends uvm_sequencer #(fp_iter_txn);
    `uvm_component_utils(fp_iter_seqr)

    function new(string name = "fp_iter_seqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass: fp_iter_seqr
