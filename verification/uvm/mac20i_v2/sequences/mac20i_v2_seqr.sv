/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class mac20i_v2_seqr extends uvm_sequencer #(mac20i_v2_txn);
    `uvm_component_utils(mac20i_v2_seqr)
    function new(string name = "mac20i_v2_seqr", uvm_component parent = null); super.new(name, parent); endfunction
endclass: mac20i_v2_seqr
