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

interface sram_bank_if;
    import memory_pkg::*;

    logic                         clk;
    logic                         rst_n;
    logic                         req_valid;
    logic                         resp_expected;
    logic                         req_ready;
    logic                         resp_valid;
    logic                         resp_ready;
    logic [PORT_IDX_W-1:0]        req_port;
    logic [THRD_W-1:0]            req_thrd;
    logic                         lr;
    logic                         sc;
    logic [BANK_ADDR_W-1:0]       raddr;
    logic [BANK_ADDR_W-1:0]       waddr;
    logic [BANK_WORD_W/8-1:0]     wstrb;
    logic [XLEN-1:0]              wdata;
    logic                         we;
    logic                         sc_succ;
    logic [PORT_IDX_W-1:0]        resp_port;
    logic [THRD_W-1:0]            resp_thrd;
    logic [XLEN-1:0]              rdata;
endinterface: sram_bank_if

