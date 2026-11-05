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

interface memory_if;
    import memory_pkg::*;

    logic                         clk;
    logic                         rst_n;
    logic                         req_we [NUM_RW_PORTS-1:0];
    logic [THRD_W-1:0]            req_thrd [NUM_RW_PORTS-1:0];
    logic                         req_is_lr [NUM_RW_PORTS-1:0];
    logic                         req_is_sc [NUM_RW_PORTS-1:0];
    logic [VIR_ADDR_W-1:0]        req_addr [NUM_RW_PORTS-1:0];
    logic [XLEN/8-1:0]            req_wstrb [NUM_RW_PORTS-1:0];
    logic [XLEN-1:0]              req_wdata [NUM_RW_PORTS-1:0];
    logic                         req_valid [NUM_RW_PORTS-1:0];
    logic [1:0]                   req_priv [NUM_RW_PORTS-1:0];
    logic                         req_ready [NUM_RW_PORTS-1:0];
    logic [THRD_W-1:0]            resp_thrd [NUM_RW_PORTS-1:0];
    logic                         resp_sc_succ [NUM_RW_PORTS-1:0];
    logic [XLEN-1:0]              resp_rdata [NUM_RW_PORTS-1:0];
    logic                         resp_valid [NUM_RW_PORTS-1:0];
    logic                         resp_ready [NUM_RW_PORTS-1:0];
    logic                         page_msg_valid [NUM_RW_PORTS-1:0];
    logic                         page_msg_ready [NUM_RW_PORTS-1:0];
    logic [PAGE_MSG_W-1:0]        page_msg_in [NUM_RW_PORTS-1:0];
    logic                         page_msg_out_ready [NUM_RW_PORTS-1:0];
    logic                         page_msg_out_valid [NUM_RW_PORTS-1:0];
    logic [PAGE_MSG_W-1:0]        page_msg_out [NUM_RW_PORTS-1:0];
    logic                         page_req_we;
    logic                         page_req_valid;
    logic                         page_req_ready;
    logic [VIR_ADDR_W-1:0]        page_req_addr;
    logic [LINE_W-1:0]            page_req_wdata;
    logic [VIR_ADDR_W-1:0]        page_resp_addr;
    logic                         page_resp_we;
    logic [LINE_W-1:0]            page_resp_wdata;
    logic                         page_resp_valid;
    logic                         page_resp_ready;
    logic                         page_transfer_done;
    logic                         page_completion_pending;
    logic [THRD_W-1:0]            page_completion_thrd;
endinterface: memory_if

