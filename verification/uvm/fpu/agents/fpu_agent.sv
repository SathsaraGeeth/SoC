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

class fpu_agent extends uvm_agent;
    `uvm_component_utils(fpu_agent)

    fpu_seqr seqr;
    fpu_drv  drv;
    fpu_mon  mon;
    uvm_analysis_port #(fpu_txn) before_ap;
    uvm_analysis_port #(fpu_txn) after_ap;

    function new(string name = "fpu_agent", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap  = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = fpu_seqr::type_id::create("seqr", this);
        drv  = fpu_drv ::type_id::create("drv", this);
        mon  = fpu_mon ::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.before_ap.connect(before_ap);
        mon.after_ap.connect(after_ap);
    endfunction
endclass: fpu_agent

