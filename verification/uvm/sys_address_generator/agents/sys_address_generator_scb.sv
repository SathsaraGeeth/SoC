/* SPDX-License-Identifier: Apache-2.0
 * Copyright 2026 Geeth Sathsara
 */
import uvm_pkg::*;
import sys_cnfg_pkg::*;
`include "uvm_macros.svh"
class sys_address_generator_scb extends uvm_scoreboard;
    `uvm_component_utils(sys_address_generator_scb)
    uvm_analysis_export #(sys_address_generator_txn) before_export, after_export;
    uvm_tlm_analysis_fifo #(sys_address_generator_txn) before_fifo, after_fifo;
    sys_address_generator_txn expected[3][$];
    function new(string name = "sys_address_generator_scb", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); before_export = new("before_export", this); before_fifo = new("before_fifo", this);
        after_export = new("after_export", this); after_fifo = new("after_fifo", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        before_export.connect(before_fifo.analysis_export); after_export.connect(after_fifo.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
        fork
            forever begin
                sys_address_generator_txn req, exp;
                logic [VIR_ADDR_W-1:0] addr;
                logic [ADDR_FLAGS_W-1:0] flags;
                logic skip;
                before_fifo.get(req);
                for (int ai = 0; ai < req.a_tiles; ai++) begin
                    for (int bi = 0; bi < req.b_tiles; bi++) begin
                        for (int qi = 0; qi < (req.kind == 2 ? 1 : req.a_tiles); qi++) begin
                            for (int beat = 0; beat < M; beat++) begin
                                exp = sys_address_generator_txn::type_id::create("expected_txn");
                                exp.kind = req.kind;
                                addr = req.kind == 2 ? calc_d_addr(req.base_addr, ai, beat, req.b_tiles, bi)
                                     : req.kind == 1 ? calc_b_addr(req.base_addr, qi, beat, req.b_tiles, bi)
                                     : calc_a_addr(req.base_addr, qi, beat, req.a_tiles, ai);
                                skip = req.dense && req.kind != 2
                                     && ((req.kind == 0 && bi != 0) || (req.kind == 1 && ai != 0 && bi == 0));
                                if (req.kind == 2) flags = ADDR_FLAGS_NONE;
                                else if ((req.dense || req.cmd_last) && ai+1 == req.a_tiles
                                      && bi+1 == req.b_tiles && qi+1 == req.a_tiles && beat+1 == M)
                                    flags = ADDR_FLAGS_END;
                                else if (beat != 0) flags = ADDR_FLAGS_CONTINUE;
                                else flags = {1'b0, req.dense ? qi+1 == req.a_tiles : req.cmd_last,
                                              req.dense ? qi == 0 : req.cmd_start};
                                exp.data = {skip, req.dense, addr, req.tid, req.mac_type, flags};
                                expected[req.kind].push_back(exp);
                            end
                        end
                    end
                end
            end
            forever begin
                sys_address_generator_txn actual, exp;
                after_fifo.get(actual);
                if (expected[actual.kind].size() == 0)
                    `uvm_error("SYS_ADDR_SCB", "Address observed without a request")
                else begin
                    exp = expected[actual.kind].pop_front();
                    if (actual.data !== exp.data)
                        `uvm_error("SYS_ADDR_SCB", $sformatf("Kind %0d mismatch expected=0x%0h actual=0x%0h", actual.kind, exp.data, actual.data))
                end
            end
        join
    endtask
endclass: sys_address_generator_scb
