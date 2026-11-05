/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"
`uvm_analysis_imp_decl(_before)
`uvm_analysis_imp_decl(_after)

class router_scb extends uvm_scoreboard;
    `uvm_component_utils(router_scb)

    uvm_analysis_imp_before #(router_txn, router_scb) before_export;
    uvm_analysis_imp_after  #(router_txn, router_scb) after_export;
    router_txn expected[$];

    function new(string name = "router_scb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        before_export = new("before_export", this);
        after_export = new("after_export", this);
    endfunction

    function void write_before(router_txn txn);
        router_txn copy;
        $cast(copy, txn.clone());
        if (copy.priv == isa_pkg::PRIV_MODE_U &&
            copy.kind inside {ROUTER_INSTR, ROUTER_DATA})
            copy.direction = 1;
        expected.push_back(copy);
    endfunction

    function void write_after(router_txn actual);
        router_txn exp;
        bit [memory_pkg::PAGE_MSG_W-1:0] expected_page;

        if (expected.size() == 0) begin
            `uvm_error("ROUTER_SCB", "Observed a transaction with no expectation")
            return;
        end
        exp = expected.pop_front();
        if (actual.kind != exp.kind)
            `uvm_error("ROUTER_SCB", "Transaction kind mismatch")

        case (exp.kind)
            ROUTER_INSTR: begin
                if (actual.direction != exp.direction ||
                    actual.route_mask != (4'b0001 << exp.direction))
                    `uvm_error("ROUTER_SCB", "Instruction selected the wrong direction")
                if (actual.addr !== exp.addr || actual.thrd !== exp.thrd ||
                    actual.priv !== exp.priv)
                    `uvm_error("ROUTER_SCB", "Instruction request payload mismatch")
                if (actual.resp_data !== exp.wdata ||
                    actual.resp_thrd !== exp.thrd)
                    `uvm_error("ROUTER_SCB", "Instruction response payload mismatch")
            end
            ROUTER_DATA: begin
                if (actual.direction != exp.direction)
                    `uvm_error("ROUTER_SCB", "Data selected the wrong target")
                if (exp.direction == 4) begin
                    if (actual.route_mask != '0)
                        `uvm_error("ROUTER_SCB", "MMIO request also selected memory")
                end else if (actual.route_mask != (4'b0001 << exp.direction))
                    `uvm_error("ROUTER_SCB", "Data selected the wrong direction")
                if (actual.addr !== exp.addr || actual.thrd !== exp.thrd ||
                    actual.priv !== exp.priv || actual.rw !== exp.rw ||
                    actual.lq !== exp.lq || actual.sc !== exp.sc ||
                    actual.wstrb !== exp.wstrb || actual.wdata !== exp.wdata)
                    `uvm_error("ROUTER_SCB", "Data request payload mismatch")
                if (actual.resp_data !== ~exp.wdata ||
                    actual.resp_sc_ok !== exp.sc ||
                    actual.resp_thrd !== exp.thrd)
                    `uvm_error("ROUTER_SCB", "Data response payload mismatch")
            end
            ROUTER_PAGE_OUT: begin
                if (actual.direction != 1 || actual.route_mask != 4'b0010 ||
                    actual.page_msg !== exp.page_msg)
                    `uvm_error("ROUTER_SCB", "Outbound page-message routing mismatch")
            end
            ROUTER_PAGE_INSTR, ROUTER_PAGE_DATA: begin
                expected_page = exp.page_msg;
                if (exp.all_sources)
                    expected_page = exp.page_msg ^ memory_pkg::PAGE_MSG_W'(3);
                if (actual.direction != exp.direction ||
                    actual.page_msg !== expected_page)
                    `uvm_error("ROUTER_SCB", "Inbound page-message priority/payload mismatch")
            end
            default: `uvm_error("ROUTER_SCB", "Unsupported transaction kind")
        endcase
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (expected.size() != 0)
            `uvm_error("ROUTER_SCB",
                       $sformatf("%0d transactions were not observed", expected.size()))
    endfunction
endclass: router_scb
