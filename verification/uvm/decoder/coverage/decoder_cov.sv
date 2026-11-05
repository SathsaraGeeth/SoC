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

class decoder_cov extends uvm_subscriber #(decoder_txn);
    `uvm_component_utils(decoder_cov)

    bit [3:0] case_id;
    bit       writes_rd;

    covergroup decode_cg;
        cp_case: coverpoint case_id {
            bins instruction_classes[] = {[0:13]};
        }
        cp_write: coverpoint writes_rd;
        cross cp_case, cp_write;
    endgroup

    function new(string name = "decoder_cov", uvm_component parent = null);
        super.new(name, parent);
        decode_cg = new();
    endfunction

    function void write(decoder_txn txn);
        case_id   = txn.case_id;
        writes_rd = txn.decoded.rf_wen;
        decode_cg.sample();
    endfunction
endclass: decoder_cov

