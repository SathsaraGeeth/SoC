/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_agent extends uvm_agent;
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_agent)
    mac_fp8_fp8_fp8_61_v2_seqr seqr;mac_fp8_fp8_fp8_61_v2_drv drv;mac_fp8_fp8_fp8_61_v2_mon mon;
    function new(string name="mac_fp8_fp8_fp8_61_v2_agent",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);seqr=mac_fp8_fp8_fp8_61_v2_seqr::type_id::create("seqr",this);drv=mac_fp8_fp8_fp8_61_v2_drv::type_id::create("drv",this);mon=mac_fp8_fp8_fp8_61_v2_mon::type_id::create("mon",this);endfunction
    function void connect_phase(uvm_phase phase);drv.seq_item_port.connect(seqr.seq_item_export);endfunction
endclass: mac_fp8_fp8_fp8_61_v2_agent
