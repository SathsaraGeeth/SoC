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

interface regfile_if;
    import core_pkg::*;

    logic                            clk;
    logic                            we;
    logic [$clog2(REG_COUNT)-1:0]    rs1_addr;
    logic [$clog2(REG_COUNT)-1:0]    rs2_addr;
    logic [$clog2(REG_COUNT)-1:0]    rs3_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0] rthrd_id;
    logic [$clog2(REG_COUNT)-1:0]    rd_addr;
    logic [$clog2(NUM_HW_THRDS)-1:0] wthrd_id;
    logic [XLEN-1:0]                 rd_wdata;
    logic [XLEN-1:0]                 rs1_data;
    logic [XLEN-1:0]                 rs2_data;
    logic [XLEN-1:0]                 rs3_data;
endinterface: regfile_if

