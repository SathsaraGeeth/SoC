/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class fp_iter_agent extends uvm_agent;
    `uvm_component_utils(fp_iter_agent)

    fp_iter_seqr seqr;
    fp_iter_drv  drv;
    fp_iter_mon  mon;

    function new(string name = "fp_iter_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = fp_iter_seqr::type_id::create("seqr", this);
        drv  = fp_iter_drv::type_id::create("drv", this);
        mon  = fp_iter_mon::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass: fp_iter_agent
