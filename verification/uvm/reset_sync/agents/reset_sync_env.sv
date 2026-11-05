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

class reset_sync_env extends uvm_env;
    `uvm_component_utils(reset_sync_env)

    reset_sync_agent u_agent;
    reset_sync_scb   u_scb;
    reset_sync_cov   u_cov;

    function new(string name = "reset_sync_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_agent = reset_sync_agent::type_id::create("u_agent", this);
        u_scb   = reset_sync_scb  ::type_id::create("u_scb", this);
        u_cov   = reset_sync_cov  ::type_id::create("u_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        u_agent.after_ap.connect(u_scb.after_export);
        u_agent.after_ap.connect(u_cov.analysis_export);
    endfunction
endclass: reset_sync_env

