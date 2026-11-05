/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_seqr extends uvm_sequencer #(sys_address_generator_txn);
    `uvm_component_utils(sys_address_generator_seqr)
    function new(string name = "sys_address_generator_seqr", uvm_component parent = null); super.new(name, parent); endfunction
endclass: sys_address_generator_seqr
