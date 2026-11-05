/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mac_fp8_fp8_fp8_61_v2_cov extends uvm_subscriber #(mac_fp8_fp8_fp8_61_v2_txn);
    `uvm_component_utils(mac_fp8_fp8_fp8_61_v2_cov)
    bit[2:0]case_id;bit[3:0]terms;covergroup mac_cg;cp_case:coverpoint case_id{bins vectors[]={[0:5]};}cp_terms:coverpoint terms{bins full_tile={8};}endgroup
    function new(string name="mac_fp8_fp8_fp8_61_v2_cov",uvm_component parent=null);super.new(name,parent);mac_cg=new();endfunction
    function void write(mac_fp8_fp8_fp8_61_v2_txn txn);case_id=txn.case_id;terms=txn.terms;mac_cg.sample();endfunction
endclass: mac_fp8_fp8_fp8_61_v2_cov
