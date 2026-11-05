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

class reset_sync_txn extends uvm_sequence_item;
    rand int unsigned high_cycles;
    rand int unsigned low_cycles;
    rand int unsigned phase_ps;
    bit               async_rst_n;
    bit               rst_n;
    int unsigned      reset_id;

    constraint c_timing {
        high_cycles inside {[2:8]};
        low_cycles  inside {[1:4]};
        phase_ps    inside {[1:9000]};
    }

    `uvm_object_utils_begin(reset_sync_txn)
        `uvm_field_int(high_cycles, UVM_ALL_ON)
        `uvm_field_int(low_cycles, UVM_ALL_ON)
        `uvm_field_int(phase_ps, UVM_ALL_ON)
        `uvm_field_int(async_rst_n, UVM_ALL_ON)
        `uvm_field_int(rst_n, UVM_ALL_ON)
        `uvm_field_int(reset_id, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "reset_sync_txn");
        super.new(name);
    endfunction
endclass: reset_sync_txn
