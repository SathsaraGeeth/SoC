/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_seqr extends uvm_sequencer #(router_txn);
    `uvm_component_utils(router_seqr)

    function new(string name = "router_seqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass: router_seqr
