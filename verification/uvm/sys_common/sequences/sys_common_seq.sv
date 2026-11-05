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

class sys_common_seq extends uvm_sequence #(sys_common_txn);
    `uvm_object_utils(sys_common_seq)
    function new(string name = "sys_common_seq");
        super.new(name);
    endfunction

    virtual task body();
        sys_common_txn txn;
        repeat (1200) begin
            txn = sys_common_txn::type_id::create("txn");
            start_item(txn);
            assert (txn.randomize()) else
                `uvm_error("SYS_COMMON_SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask
endclass: sys_common_seq

