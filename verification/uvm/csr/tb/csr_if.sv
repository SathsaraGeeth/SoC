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

interface csr_if;
    import core_pkg::*;

    logic                            clk;
    logic                            rst_n;
    logic                            we;
    logic [XLEN-1:0]                 thread_id_vec [NUM_HW_THRDS-1:0];
    logic [NUM_HW_THRDS-1:0]         irq_timer_vec;
    logic [NUM_HW_THRDS-1:0]         irq_pending_vec;
    logic [$clog2(CSR_COUNT)-1:0]    rs1_addr_vec [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                 rs1_data_vec [NUM_HW_THRDS-1:0];
    logic [$clog2(CSR_COUNT)-1:0]    rd_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0] wthrd_id;
    logic [XLEN-1:0]                 rd_wdata;
    logic                            trap_we;
    logic [XLEN-1:0]                 trap_mepc;
    logic [XLEN-1:0]                 trap_mcause;
    logic [XLEN-1:0]                 trap_tval;
    logic                            trap_to_s;
    logic                            mret_we;
    logic                            sret_we;
    logic [isa_pkg::PRIV_MODE_W-1:0] priv_mode_vec [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                 medeleg_vec [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                 mideleg_vec [NUM_HW_THRDS-1:0];
endinterface: csr_if

