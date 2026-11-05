/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_agent extends uvm_agent;
    `uvm_component_utils(sys_address_generator_agent)
    sys_address_generator_seqr seqr; sys_address_generator_drv drv; sys_address_generator_mon mon;
    function new(string name = "sys_address_generator_agent", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); seqr = sys_address_generator_seqr::type_id::create("seqr", this);
        drv = sys_address_generator_drv::type_id::create("drv", this); mon = sys_address_generator_mon::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass: sys_address_generator_agent
