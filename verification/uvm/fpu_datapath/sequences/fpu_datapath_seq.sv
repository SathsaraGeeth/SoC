/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_seq extends uvm_sequence #(fpu_datapath_txn);
    `uvm_object_utils(fpu_datapath_seq)

    function new(string name = "fpu_datapath_seq");
        super.new(name);
    endfunction

    virtual task body();
        fpu_datapath_txn txn;

        repeat (160) begin
            txn = fpu_datapath_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else
                `uvm_error("FPU_DP_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask: body
endclass: fpu_datapath_seq
