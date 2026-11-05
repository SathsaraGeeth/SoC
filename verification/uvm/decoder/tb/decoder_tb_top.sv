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

`include "uvm_macros.svh"
import uvm_pkg::*;

module decoder_tb_top;
    decoder_if vif();

    decoder dut (
        .i_instr   (vif.instr),
        .o_decoded (vif.decoded)
    );

    initial begin
        uvm_config_db#(virtual decoder_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.sample_clk = 1'b0;
        vif.instr      = '0;
        $dumpfile("decoder_tb.vcd");
        $dumpvars(0, decoder_tb_top);
    end

    always #5ns vif.sample_clk = ~vif.sample_clk;
endmodule: decoder_tb_top

