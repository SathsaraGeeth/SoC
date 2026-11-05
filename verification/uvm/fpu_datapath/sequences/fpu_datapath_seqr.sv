/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_seqr extends uvm_sequencer #(fpu_datapath_txn);
    `uvm_component_utils(fpu_datapath_seqr)

    function new(string name = "fpu_datapath_seqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass: fpu_datapath_seqr
