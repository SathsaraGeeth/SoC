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

interface circular_buffer_if;
    localparam int WIDTH = 8;
    localparam int DEPTH = 8;

    logic                         clk;
    logic                         rst_n;
    logic [WIDTH-1:0]             head_data;
    logic                         deq_ready;
    logic                         deq_valid;
    logic [WIDTH-1:0]             enq_tail_data;
    logic                         enq_valid;
    logic                         enq_ready;
    logic                         full;
    logic                         empty;
    logic [$clog2(DEPTH+1)-1:0]   level;
    logic                         clr_n;
endinterface: circular_buffer_if

