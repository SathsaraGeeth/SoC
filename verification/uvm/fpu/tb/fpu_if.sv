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

interface fpu_if;
    import core_pkg::*;

    logic                            clk;
    logic                            rst_n;
    issue_instr_t                    issued_instr;
    logic                            req_ready;
    logic                            req_valid;
    logic [$clog2(NUM_HW_THRDS)-1:0] res_thrd_id;
    logic                            res_valid;
    logic                            res_ready;
    logic [VIR_ADDR_W-1:0]           result;
endinterface: fpu_if

