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

class fpu_cov extends uvm_subscriber #(fpu_txn);
    `uvm_component_utils(fpu_cov)

    bit [4:0] op;
    bit [1:0] classification;

    covergroup fpu_cg;
        cp_op: coverpoint op;
        cp_class: coverpoint classification;
        cross cp_op, cp_class;
    endgroup

    function new(string name = "fpu_cov", uvm_component parent = null);
        super.new(name, parent);
        fpu_cg = new();
    endfunction

    function void write(fpu_txn txn);
        op = txn.op;
        classification = txn.a[30:23] == 8'hff ? 3 :
                         txn.a[30:23] == 8'h00 ? 0 :
                         txn.a[31] ? 1 : 2;
        fpu_cg.sample();
    endfunction
endclass: fpu_cov

