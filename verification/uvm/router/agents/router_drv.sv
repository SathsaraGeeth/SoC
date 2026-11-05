/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_drv extends uvm_driver #(router_txn);
    `uvm_component_utils(router_drv)

    virtual router_if vif;
    uvm_analysis_port #(router_txn) before_ap;

    function new(string name = "router_drv", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual router_if)::get(this, "", "vif", vif))
            `uvm_fatal("ROUTER_DRV", "Virtual interface not set")
    endfunction

    task automatic wait_cycles(int unsigned count);
        repeat (count) @(posedge vif.clk);
    endtask

    task automatic drive_instruction(router_txn txn);
        int direction;

        direction = txn.direction;
        @(negedge vif.clk);
        vif.resp_instr_ready <= 1'b0;
        vif.req_instr_addr <= txn.addr;
        vif.req_instr_thrd_id <= txn.thrd;
        vif.req_instr_priv <= txn.priv;
        vif.req_instr_valid <= 1'b1;
        do @(posedge vif.clk); while (!vif.req_instr_ready);
        @(negedge vif.clk);
        vif.req_instr_valid <= 1'b0;

        vif.mem_resp_instr_rdata[direction] <= txn.wdata;
        vif.mem_resp_instr_thrd_id[direction] <= txn.thrd;
        vif.mem_resp_instr_valid[direction] <= 1'b1;
        do @(posedge vif.clk); while (!vif.mem_resp_instr_ready[direction]);
        @(negedge vif.clk);
        vif.mem_resp_instr_valid[direction] <= 1'b0;
        wait (vif.resp_instr_valid === 1'b1);
        wait_cycles(txn.stall_cycles);
        @(negedge vif.clk);
        vif.resp_instr_ready <= 1'b1;
        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.resp_instr_ready <= 1'b0;
    endtask: drive_instruction

    task automatic drive_data(router_txn txn);
        int direction;

        direction = txn.direction;
        @(negedge vif.clk);
        vif.resp_data_ready <= 1'b0;
        vif.req_data_addr <= txn.addr;
        vif.req_data_thrd_id <= txn.thrd;
        vif.req_data_priv <= txn.priv;
        vif.req_data_rw <= txn.rw;
        vif.req_data_lq <= txn.lq;
        vif.req_data_sc <= txn.sc;
        vif.req_data_wstrb <= txn.wstrb;
        vif.req_data_wdata <= txn.wdata;
        vif.req_data_valid <= 1'b1;
        do @(posedge vif.clk); while (!vif.req_data_ready);
        @(negedge vif.clk);
        vif.req_data_valid <= 1'b0;

        if (direction == 4) begin
            vif.mmio_resp_rdata <= ~txn.wdata;
            vif.mmio_resp_sc_ok <= txn.sc;
            vif.mmio_resp_thrd_id <= txn.thrd;
            vif.mmio_resp_valid <= 1'b1;
            do @(posedge vif.clk); while (!vif.mmio_resp_ready);
            @(negedge vif.clk);
            vif.mmio_resp_valid <= 1'b0;
        end else begin
            vif.mem_resp_data_rdata[direction] <= ~txn.wdata;
            vif.mem_resp_data_sc_ok[direction] <= txn.sc;
            vif.mem_resp_data_thrd_id[direction] <= txn.thrd;
            vif.mem_resp_data_valid[direction] <= 1'b1;
            do @(posedge vif.clk); while (!vif.mem_resp_data_ready[direction]);
            @(negedge vif.clk);
            vif.mem_resp_data_valid[direction] <= 1'b0;
        end

        wait (vif.resp_data_valid === 1'b1);
        wait_cycles(txn.stall_cycles);
        @(negedge vif.clk);
        vif.resp_data_ready <= 1'b1;
        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.resp_data_ready <= 1'b0;
    endtask: drive_data

    task automatic drive_page_out(router_txn txn);
        @(negedge vif.clk);
        vif.core_page_msg <= txn.page_msg;
        vif.core_page_msg_valid <= 1'b1;
        do @(posedge vif.clk); while (!vif.core_page_msg_ready);
        @(negedge vif.clk);
        vif.core_page_msg_valid <= 1'b0;
    endtask: drive_page_out

    task automatic drive_page_input(router_txn txn, bit is_instr);
        int direction;

        @(negedge vif.clk);
        vif.core_page_msg_instr_ready <= 1'b0;
        vif.core_page_msg_data_ready <= 1'b0;
        if (txn.all_sources) begin
            for (direction = 0; direction < 4; direction++) begin
                if (is_instr) begin
                    vif.mem_page_msg_instr[direction] <= txn.page_msg ^
                        memory_pkg::PAGE_MSG_W'(direction);
                    vif.mem_page_msg_instr_valid[direction] <= 1'b1;
                end else begin
                    vif.mem_page_msg_data[direction] <= txn.page_msg ^
                        memory_pkg::PAGE_MSG_W'(direction);
                    vif.mem_page_msg_data_valid[direction] <= 1'b1;
                end
            end
        end else if (is_instr) begin
            vif.mem_page_msg_instr[txn.direction] <= txn.page_msg;
            vif.mem_page_msg_instr_valid[txn.direction] <= 1'b1;
        end else begin
            vif.mem_page_msg_data[txn.direction] <= txn.page_msg;
            vif.mem_page_msg_data_valid[txn.direction] <= 1'b1;
        end

        if (is_instr)
            do @(posedge vif.clk); while (!vif.mem_page_msg_instr_ready[txn.direction]);
        else
            do @(posedge vif.clk); while (!vif.mem_page_msg_data_ready[txn.direction]);
        @(negedge vif.clk);
        for (direction = 0; direction < 4; direction++) begin
            vif.mem_page_msg_instr_valid[direction] <= 1'b0;
            vif.mem_page_msg_data_valid[direction] <= 1'b0;
        end

        if (is_instr)
            wait (vif.core_page_msg_instr_valid === 1'b1);
        else
            wait (vif.core_page_msg_data_valid === 1'b1);
        wait_cycles(txn.stall_cycles);
        @(negedge vif.clk);
        if (is_instr)
            vif.core_page_msg_instr_ready <= 1'b1;
        else
            vif.core_page_msg_data_ready <= 1'b1;
        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.core_page_msg_instr_ready <= 1'b0;
        vif.core_page_msg_data_ready <= 1'b0;
    endtask: drive_page_input

    task run_phase(uvm_phase phase);
        router_txn txn;

        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            before_ap.write(txn);
            case (txn.kind)
                ROUTER_INSTR:      drive_instruction(txn);
                ROUTER_DATA:       drive_data(txn);
                ROUTER_PAGE_OUT:   drive_page_out(txn);
                ROUTER_PAGE_INSTR: drive_page_input(txn, 1'b1);
                ROUTER_PAGE_DATA:  drive_page_input(txn, 1'b0);
                default: `uvm_fatal("ROUTER_DRV", "Unknown transaction kind")
            endcase
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: router_drv
