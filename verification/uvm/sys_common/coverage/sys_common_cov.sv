/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import uvm_pkg::*;
`include "uvm_macros.svh"
class sys_common_cov extends uvm_subscriber #(sys_common_txn);
    `uvm_component_utils(sys_common_cov)
    bit en, clear, start;
    bit [2:0] ptr;
    covergroup sys_common_cg;
        cp_en: coverpoint en;
        cp_clear: coverpoint clear;
        cp_start: coverpoint start;
        cp_ptr: coverpoint ptr { bins legal[] = {[0:4]}; }
        cross cp_en, cp_clear;
    endgroup
    function new(string name = "sys_common_cov", uvm_component parent = null);
        super.new(name, parent);
        sys_common_cg = new();
    endfunction
    function void write(sys_common_txn txn);
        en = txn.en; clear = !txn.clr_n; start = txn.start; ptr = txn.ptr;
        sys_common_cg.sample();
    endfunction
endclass: sys_common_cov

