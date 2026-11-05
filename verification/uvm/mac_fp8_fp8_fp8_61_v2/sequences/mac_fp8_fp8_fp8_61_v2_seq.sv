/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_seq extends uvm_sequence #(mac_fp8_fp8_fp8_61_v2_txn);
    `uvm_object_utils(mac_fp8_fp8_fp8_61_v2_seq)
    function new(string name = "mac_fp8_fp8_fp8_61_v2_seq"); super.new(name); endfunction
    virtual task body(); mac_fp8_fp8_fp8_61_v2_txn txn; repeat (120) begin txn = mac_fp8_fp8_fp8_61_v2_txn::type_id::create("txn"); start_item(txn); assert(txn.randomize()) else `uvm_error("MAC_FP8_SEQ", "Randomization failed") finish_item(txn); end endtask
endclass: mac_fp8_fp8_fp8_61_v2_seq
