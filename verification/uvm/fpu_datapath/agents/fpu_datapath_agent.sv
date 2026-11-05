/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

import uvm_pkg::*;
`include "uvm_macros.svh"

class fpu_datapath_agent extends uvm_agent;
    `uvm_component_utils(fpu_datapath_agent)

    fpu_datapath_seqr seqr;
    fpu_datapath_drv  drv;
    fpu_datapath_mon  mon;

    function new(string name = "fpu_datapath_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = fpu_datapath_seqr::type_id::create("seqr", this);
        drv  = fpu_datapath_drv::type_id::create("drv", this);
        mon  = fpu_datapath_mon::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass: fpu_datapath_agent
