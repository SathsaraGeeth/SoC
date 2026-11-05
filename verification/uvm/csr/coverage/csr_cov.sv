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

class csr_cov extends uvm_subscriber #(csr_txn);
    `uvm_component_utils(csr_cov)

    bit [2:0] kind;
    bit [4:0] csr_addr;
    bit [1:0] privilege;

    covergroup csr_cg;
        cp_kind: coverpoint kind;
        cp_addr: coverpoint csr_addr;
        cp_priv: coverpoint privilege;
        cross cp_kind, cp_priv;
    endgroup

    function new(string name = "csr_cov", uvm_component parent = null);
        super.new(name, parent);
        csr_cg = new();
    endfunction

    function void write(csr_txn txn);
        kind      = txn.kind;
        csr_addr  = txn.rs_addr;
        privilege = txn.priv_mode;
        csr_cg.sample();
    endfunction
endclass: csr_cov

