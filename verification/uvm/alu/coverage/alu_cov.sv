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

class alu_cov extends uvm_subscriber #(alu_txn);
    `uvm_component_utils(alu_cov)

    bit [3:0] op;
    bit       lane;
    bit [3:0] control_kind;
    bit       word_op;

    covergroup alu_cg;
        cp_op:      coverpoint op;
        cp_lane:    coverpoint lane;
        cp_control: coverpoint control_kind {
            bins data   = {0};
            bins branch = {1};
            bins jump   = {2};
            bins jalr   = {3};
        }
        cp_word: coverpoint word_op;
        cross cp_op, cp_lane;
    endgroup

    function new(string name = "alu_cov", uvm_component parent = null);
        super.new(name, parent);
        alu_cg = new();
    endfunction

    function void write(alu_txn txn);
        op           = txn.op;
        lane         = txn.lane;
        control_kind = txn.control_kind;
        word_op      = txn.word_op;
        alu_cg.sample();
    endfunction
endclass: alu_cov

