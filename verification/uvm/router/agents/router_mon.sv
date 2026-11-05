/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_mon extends uvm_monitor;
    `uvm_component_utils(router_mon)

    virtual router_if vif;
    uvm_analysis_port #(router_txn) after_ap;

    function new(string name = "router_mon", uvm_component parent = null);
        super.new(name, parent);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual router_if)::get(this, "", "vif", vif))
            `uvm_fatal("ROUTER_MON", "Virtual interface not set")
    endfunction

    task automatic monitor_instruction();
        router_txn txn;
        int direction;

        txn = router_txn::type_id::create("instr_txn");
        txn.kind = ROUTER_INSTR;
        txn.addr = vif.req_instr_addr;
        txn.thrd = vif.req_instr_thrd_id;
        txn.priv = vif.req_instr_priv;
        txn.route_mask = '0;
        for (direction = 0; direction < 4; direction++) begin
            txn.route_mask[direction] = vif.mem_req_instr_valid[direction];
            if (vif.mem_req_instr_valid[direction])
                txn.direction = direction;
        end
        do @(posedge vif.clk);
        while (!(vif.resp_instr_valid && vif.resp_instr_ready));
        txn.resp_data = vif.resp_instr;
        txn.resp_thrd = vif.resp_instr_thrd_id;
        after_ap.write(txn);
    endtask: monitor_instruction

    task automatic monitor_data();
        router_txn txn;
        int direction;

        txn = router_txn::type_id::create("data_txn");
        txn.kind = ROUTER_DATA;
        txn.addr = vif.req_data_addr;
        txn.thrd = vif.req_data_thrd_id;
        txn.priv = vif.req_data_priv;
        txn.rw = vif.req_data_rw;
        txn.lq = vif.req_data_lq;
        txn.sc = vif.req_data_sc;
        txn.wstrb = vif.req_data_wstrb;
        txn.wdata = vif.req_data_wdata;
        txn.route_mask = '0;
        if (vif.mmio_req_valid)
            txn.direction = 4;
        else begin
            for (direction = 0; direction < 4; direction++) begin
                txn.route_mask[direction] = vif.mem_req_data_valid[direction];
                if (vif.mem_req_data_valid[direction])
                    txn.direction = direction;
            end
        end
        do @(posedge vif.clk);
        while (!(vif.resp_data_valid && vif.resp_data_ready));
        txn.resp_data = vif.resp_data_rdata;
        txn.resp_sc_ok = vif.resp_data_sc_ok;
        txn.resp_thrd = vif.resp_data_thrd_id;
        after_ap.write(txn);
    endtask: monitor_data

    task automatic monitor_page_out();
        router_txn txn;
        int direction;

        txn = router_txn::type_id::create("page_out_txn");
        txn.kind = ROUTER_PAGE_OUT;
        txn.page_msg = vif.core_page_msg;
        txn.route_mask = '0;
        for (direction = 0; direction < 4; direction++) begin
            txn.route_mask[direction] = vif.mem_page_msg_valid[direction];
            if (vif.mem_page_msg_valid[direction])
                txn.direction = direction;
        end
        after_ap.write(txn);
    endtask: monitor_page_out

    task automatic monitor_page_input(bit is_instr, int direction);
        router_txn txn;

        txn = router_txn::type_id::create("page_input_txn");
        txn.kind = is_instr ? ROUTER_PAGE_INSTR : ROUTER_PAGE_DATA;
        txn.direction = direction;
        txn.page_msg = is_instr ? vif.mem_page_msg_instr[direction] :
                                  vif.mem_page_msg_data[direction];
        if (is_instr) begin
            do @(posedge vif.clk);
            while (!(vif.core_page_msg_instr_valid &&
                     vif.core_page_msg_instr_ready));
            txn.page_msg = vif.core_page_msg_instr;
        end else begin
            do @(posedge vif.clk);
            while (!(vif.core_page_msg_data_valid &&
                     vif.core_page_msg_data_ready));
            txn.page_msg = vif.core_page_msg_data;
        end
        after_ap.write(txn);
    endtask: monitor_page_input

    task automatic check_stability();
        bit [core_pkg::XLEN-1:0] instr_data;
        bit [$clog2(core_pkg::NUM_HW_THRDS)-1:0] instr_thrd;
        bit [core_pkg::XLEN-1:0] data;
        bit data_sc;
        bit [$clog2(core_pkg::NUM_HW_THRDS)-1:0] data_thrd;
        bit [memory_pkg::PAGE_MSG_W-1:0] page_instr;
        bit [memory_pkg::PAGE_MSG_W-1:0] page_data;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.resp_instr_valid && !vif.resp_instr_ready) begin
                instr_data = vif.resp_instr;
                instr_thrd = vif.resp_instr_thrd_id;
                @(posedge vif.clk);
                if (vif.resp_instr_valid && !vif.resp_instr_ready &&
                    ({vif.resp_instr, vif.resp_instr_thrd_id} !==
                     {instr_data, instr_thrd}))
                    `uvm_error("ROUTER_MON", "Instruction response changed under backpressure")
            end
            if (vif.rst_n && vif.resp_data_valid && !vif.resp_data_ready) begin
                data = vif.resp_data_rdata;
                data_sc = vif.resp_data_sc_ok;
                data_thrd = vif.resp_data_thrd_id;
                @(posedge vif.clk);
                if (vif.resp_data_valid && !vif.resp_data_ready &&
                    ({vif.resp_data_rdata, vif.resp_data_sc_ok,
                      vif.resp_data_thrd_id} !== {data, data_sc, data_thrd}))
                    `uvm_error("ROUTER_MON", "Data response changed under backpressure")
            end
            if (vif.rst_n && vif.core_page_msg_instr_valid &&
                !vif.core_page_msg_instr_ready) begin
                page_instr = vif.core_page_msg_instr;
                @(posedge vif.clk);
                if (vif.core_page_msg_instr_valid &&
                    !vif.core_page_msg_instr_ready &&
                    vif.core_page_msg_instr !== page_instr)
                    `uvm_error("ROUTER_MON", "Instruction page message changed under backpressure")
            end
            if (vif.rst_n && vif.core_page_msg_data_valid &&
                !vif.core_page_msg_data_ready) begin
                page_data = vif.core_page_msg_data;
                @(posedge vif.clk);
                if (vif.core_page_msg_data_valid &&
                    !vif.core_page_msg_data_ready &&
                    vif.core_page_msg_data !== page_data)
                    `uvm_error("ROUTER_MON", "Data page message changed under backpressure")
            end
        end
    endtask: check_stability

    task automatic collect_transactions();
        int direction;
        bit found;

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n)
                continue;
            if (vif.req_instr_valid && vif.req_instr_ready)
                monitor_instruction();
            else if (vif.req_data_valid && vif.req_data_ready)
                monitor_data();
            else if (vif.core_page_msg_valid && vif.core_page_msg_ready)
                monitor_page_out();
            else begin
                found = 1'b0;
                for (direction = 3; direction >= 0; direction--) begin
                    if (!found && vif.mem_page_msg_instr_valid[direction] &&
                        vif.mem_page_msg_instr_ready[direction]) begin
                        found = 1'b1;
                        monitor_page_input(1'b1, direction);
                    end
                end
                for (direction = 3; direction >= 0; direction--) begin
                    if (!found && vif.mem_page_msg_data_valid[direction] &&
                        vif.mem_page_msg_data_ready[direction]) begin
                        found = 1'b1;
                        monitor_page_input(1'b0, direction);
                    end
                end
            end
        end
    endtask: collect_transactions

    task run_phase(uvm_phase phase);
        fork
            collect_transactions();
            check_stability();
        join
    endtask: run_phase
endclass: router_mon
