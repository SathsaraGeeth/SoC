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

class sram_bank_agent extends uvm_agent;
    `uvm_component_utils(sram_bank_agent)

    sram_bank_seqr u_seqr;
    sram_bank_drv  u_drv;
    sram_bank_mon  u_mon;

    function new(string name = "sram_bank_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_seqr = sram_bank_seqr::type_id::create("u_seqr", this);
        u_drv  = sram_bank_drv::type_id::create("u_drv", this);
        u_mon  = sram_bank_mon::type_id::create("u_mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        u_drv.seq_item_port.connect(u_seqr.seq_item_export);
    endfunction
endclass: sram_bank_agent

