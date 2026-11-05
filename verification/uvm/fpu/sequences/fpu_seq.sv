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

class fpu_seq extends uvm_sequence #(fpu_txn);
    `uvm_object_utils(fpu_seq)

    function new(string name = "fpu_seq");
        super.new(name);
    endfunction

    virtual task body();
        fpu_txn txn;

        repeat (1800) begin
            txn = fpu_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else
                `uvm_error("FPU_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask: body
endclass: fpu_seq

