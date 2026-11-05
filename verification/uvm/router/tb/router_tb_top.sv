/* SPDX-License-Identifier: Apache-2.0 */

`include "uvm_macros.svh"
import uvm_pkg::*;

module router_tb_top;
    router_if vif();

    router #(
        .C_X (0),
        .C_Y (0)
    ) dut (
        .i_clk                          (vif.clk),
        .i_rst_n                        (vif.rst_n),
        .i_req_instr_valid              (vif.req_instr_valid),
        .o_req_instr_ready              (vif.req_instr_ready),
        .i_req_instr_addr               (vif.req_instr_addr),
        .i_req_instr_thrd_id            (vif.req_instr_thrd_id),
        .i_req_instr_priv               (vif.req_instr_priv),
        .o_resp_instr_valid             (vif.resp_instr_valid),
        .i_resp_instr_ready             (vif.resp_instr_ready),
        .o_resp_instr                   (vif.resp_instr),
        .o_resp_instr_thrd_id           (vif.resp_instr_thrd_id),
        .i_req_data_valid               (vif.req_data_valid),
        .o_req_data_ready               (vif.req_data_ready),
        .i_req_data_addr                (vif.req_data_addr),
        .i_req_data_thrd_id             (vif.req_data_thrd_id),
        .i_req_data_priv                (vif.req_data_priv),
        .i_req_data_rw                  (vif.req_data_rw),
        .i_req_data_lq                  (vif.req_data_lq),
        .i_req_data_sc                  (vif.req_data_sc),
        .i_req_data_wstrb               (vif.req_data_wstrb),
        .i_req_data_wdata               (vif.req_data_wdata),
        .o_resp_data_valid              (vif.resp_data_valid),
        .i_resp_data_ready              (vif.resp_data_ready),
        .o_resp_data_rdata              (vif.resp_data_rdata),
        .o_resp_data_sc_ok              (vif.resp_data_sc_ok),
        .o_resp_data_thrd_id            (vif.resp_data_thrd_id),
        .o_mmio_req_valid               (vif.mmio_req_valid),
        .i_mmio_req_ready               (vif.mmio_req_ready),
        .o_mmio_req_addr                (vif.mmio_req_addr),
        .o_mmio_req_thrd_id             (vif.mmio_req_thrd_id),
        .o_mmio_req_priv                (vif.mmio_req_priv),
        .o_mmio_req_rw                  (vif.mmio_req_rw),
        .o_mmio_req_wstrb               (vif.mmio_req_wstrb),
        .o_mmio_req_wdata               (vif.mmio_req_wdata),
        .i_mmio_resp_valid              (vif.mmio_resp_valid),
        .o_mmio_resp_ready              (vif.mmio_resp_ready),
        .i_mmio_resp_rdata              (vif.mmio_resp_rdata),
        .i_mmio_resp_sc_ok              (vif.mmio_resp_sc_ok),
        .i_mmio_resp_thrd_id            (vif.mmio_resp_thrd_id),
        .i_core_page_msg_valid          (vif.core_page_msg_valid),
        .i_core_page_msg                (vif.core_page_msg),
        .o_core_page_msg_ready          (vif.core_page_msg_ready),
        .o_core_page_msg_instr_valid    (vif.core_page_msg_instr_valid),
        .o_core_page_msg_instr          (vif.core_page_msg_instr),
        .i_core_page_msg_instr_ready    (vif.core_page_msg_instr_ready),
        .o_core_page_msg_data_valid     (vif.core_page_msg_data_valid),
        .o_core_page_msg_data           (vif.core_page_msg_data),
        .i_core_page_msg_data_ready     (vif.core_page_msg_data_ready),
        .o_mem_page_msg_valid           (vif.mem_page_msg_valid),
        .o_mem_page_msg                 (vif.mem_page_msg),
        .i_mem_page_msg_ready           (vif.mem_page_msg_ready),
        .i_mem_page_msg_instr_valid     (vif.mem_page_msg_instr_valid),
        .i_mem_page_msg_instr           (vif.mem_page_msg_instr),
        .o_mem_page_msg_instr_ready     (vif.mem_page_msg_instr_ready),
        .i_mem_page_msg_data_valid      (vif.mem_page_msg_data_valid),
        .i_mem_page_msg_data            (vif.mem_page_msg_data),
        .o_mem_page_msg_data_ready      (vif.mem_page_msg_data_ready),
        .o_mem_req_instr_valid          (vif.mem_req_instr_valid),
        .i_mem_req_instr_ready          (vif.mem_req_instr_ready),
        .o_mem_req_instr_addr           (vif.mem_req_instr_addr),
        .o_mem_req_instr_thrd_id        (vif.mem_req_instr_thrd_id),
        .o_mem_req_instr_priv           (vif.mem_req_instr_priv),
        .i_mem_resp_instr_valid         (vif.mem_resp_instr_valid),
        .o_mem_resp_instr_ready         (vif.mem_resp_instr_ready),
        .i_mem_resp_instr_rdata         (vif.mem_resp_instr_rdata),
        .i_mem_resp_instr_thrd_id       (vif.mem_resp_instr_thrd_id),
        .o_mem_req_data_valid           (vif.mem_req_data_valid),
        .i_mem_req_data_ready           (vif.mem_req_data_ready),
        .o_mem_req_data_addr            (vif.mem_req_data_addr),
        .o_mem_req_data_thrd_id         (vif.mem_req_data_thrd_id),
        .o_mem_req_data_priv            (vif.mem_req_data_priv),
        .o_mem_req_data_rw              (vif.mem_req_data_rw),
        .o_mem_req_data_lq              (vif.mem_req_data_lq),
        .o_mem_req_data_sc              (vif.mem_req_data_sc),
        .o_mem_req_data_wstrb           (vif.mem_req_data_wstrb),
        .o_mem_req_data_wdata           (vif.mem_req_data_wdata),
        .i_mem_resp_data_valid          (vif.mem_resp_data_valid),
        .o_mem_resp_data_ready          (vif.mem_resp_data_ready),
        .i_mem_resp_data_rdata          (vif.mem_resp_data_rdata),
        .i_mem_resp_data_sc_ok          (vif.mem_resp_data_sc_ok),
        .i_mem_resp_data_thrd_id        (vif.mem_resp_data_thrd_id)
    );

    initial begin
        vif.clk = 1'b0;
        vif.rst_n = 1'b0;
        vif.req_instr_valid = 1'b0;
        vif.req_instr_addr = '0;
        vif.req_instr_thrd_id = '0;
        vif.req_instr_priv = '0;
        vif.resp_instr_ready = 1'b0;
        vif.req_data_valid = 1'b0;
        vif.req_data_addr = '0;
        vif.req_data_thrd_id = '0;
        vif.req_data_priv = '0;
        vif.req_data_rw = 1'b0;
        vif.req_data_lq = 1'b0;
        vif.req_data_sc = 1'b0;
        vif.req_data_wstrb = '0;
        vif.req_data_wdata = '0;
        vif.resp_data_ready = 1'b0;
        vif.mmio_req_ready = 1'b1;
        vif.mmio_resp_valid = 1'b0;
        vif.mmio_resp_rdata = '0;
        vif.mmio_resp_sc_ok = 1'b0;
        vif.mmio_resp_thrd_id = '0;
        vif.core_page_msg_valid = 1'b0;
        vif.core_page_msg = '0;
        vif.core_page_msg_instr_ready = 1'b0;
        vif.core_page_msg_data_ready = 1'b0;
        for (int direction = 0; direction < 4; direction++) begin
            vif.mem_page_msg_ready[direction] = 1'b1;
            vif.mem_page_msg_instr_valid[direction] = 1'b0;
            vif.mem_page_msg_instr[direction] = '0;
            vif.mem_page_msg_data_valid[direction] = 1'b0;
            vif.mem_page_msg_data[direction] = '0;
            vif.mem_req_instr_ready[direction] = 1'b1;
            vif.mem_resp_instr_valid[direction] = 1'b0;
            vif.mem_resp_instr_rdata[direction] = '0;
            vif.mem_resp_instr_thrd_id[direction] = '0;
            vif.mem_req_data_ready[direction] = 1'b1;
            vif.mem_resp_data_valid[direction] = 1'b0;
            vif.mem_resp_data_rdata[direction] = '0;
            vif.mem_resp_data_sc_ok[direction] = 1'b0;
            vif.mem_resp_data_thrd_id[direction] = '0;
        end
        repeat (5) @(posedge vif.clk);
        vif.rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual router_if)::set(null, "*", "vif", vif);
        run_test();
    end

    always #5ns vif.clk = ~vif.clk;

    initial begin
        $dumpfile("router_tb.vcd");
        $dumpvars(0, router_tb_top);
    end
endmodule: router_tb_top
