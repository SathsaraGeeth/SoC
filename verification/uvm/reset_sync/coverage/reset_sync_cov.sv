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

class reset_sync_cov extends uvm_subscriber #(reset_sync_txn);
    `uvm_component_utils(reset_sync_cov)

    bit async_rst_n;
    bit rst_n;

    covergroup reset_cg;
        cp_async: coverpoint async_rst_n;
        cp_sync:  coverpoint rst_n;
        cross cp_async, cp_sync;
    endgroup

    function new(string name = "reset_sync_cov", uvm_component parent = null);
        super.new(name, parent);
        reset_cg = new();
    endfunction

    function void write(reset_sync_txn txn);
        async_rst_n = txn.async_rst_n;
        rst_n       = txn.rst_n;
        reset_cg.sample();
    endfunction
endclass: reset_sync_cov

