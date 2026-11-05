/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_seq extends uvm_sequence #(fp_iter_txn);
    `uvm_object_utils(fp_iter_seq)

    function new(string name = "fp_iter_seq");
        super.new(name);
    endfunction

    virtual task body();
        fp_iter_txn txn;

        for (int item = 0; item < 96; item++) begin
            txn = fp_iter_txn::type_id::create("txn");
            start_item(txn);
            txn.kind          = item[1:0];
            txn.thrd          = 64'(item + 16);
            txn.bypass_result = {$urandom(), $urandom()};
            finish_item(txn);
        end
    endtask
endclass: fp_iter_seq
