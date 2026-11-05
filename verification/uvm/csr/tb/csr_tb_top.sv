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
import core_pkg::*;

module csr_tb_top;
    csr_if vif();

    csr dut (
        .i_clk            (vif.clk),
        .i_rst_n          (vif.rst_n),
        .i_we             (vif.we),
        .i_thread_id_vec  (vif.thread_id_vec),
        .i_irq_timer_vec  (vif.irq_timer_vec),
        .o_irq_pending_vec(vif.irq_pending_vec),
        .i_rs1_addr_vec   (vif.rs1_addr_vec),
        .o_rs1_data_vec   (vif.rs1_data_vec),
        .i_rd_addr        (vif.rd_addr),
        .i_wthrd_id       (vif.wthrd_id),
        .i_rd_wdata       (vif.rd_wdata),
        .i_trap_we        (vif.trap_we),
        .i_trap_mepc      (vif.trap_mepc),
        .i_trap_mcause    (vif.trap_mcause),
        .i_trap_tval      (vif.trap_tval),
        .i_trap_to_s      (vif.trap_to_s),
        .i_mret_we        (vif.mret_we),
        .i_sret_we        (vif.sret_we),
        .o_priv_mode_vec  (vif.priv_mode_vec),
        .o_medeleg_vec    (vif.medeleg_vec),
        .o_mideleg_vec    (vif.mideleg_vec)
    );

    initial begin
        uvm_config_db#(virtual csr_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        vif.clk = 1'b0;
        vif.rst_n = 1'b0;
        vif.we = 1'b0;
        vif.irq_timer_vec = '0;
        vif.rd_addr = '0;
        vif.wthrd_id = '0;
        vif.rd_wdata = '0;
        vif.trap_we = 1'b0;
        vif.trap_mepc = '0;
        vif.trap_mcause = '0;
        vif.trap_tval = '0;
        vif.trap_to_s = 1'b0;
        vif.mret_we = 1'b0;
        vif.sret_we = 1'b0;
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            vif.thread_id_vec[t] = XLEN'(t);
            vif.rs1_addr_vec[t]  = CSR_THREAD_ID;
        end
        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
        $dumpfile("csr_tb.vcd");
        $dumpvars(0, csr_tb_top);
    end

    always #5ns vif.clk = ~vif.clk;
endmodule: csr_tb_top

