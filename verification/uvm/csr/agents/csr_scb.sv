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

import uvm_pkg::*;
import core_pkg::*;
`include "uvm_macros.svh"

class csr_scb extends uvm_scoreboard;
    `uvm_component_utils(csr_scb)

    uvm_analysis_export #(csr_txn) after_export;
    uvm_tlm_analysis_fifo #(csr_txn) after_fifo;
    bit [XLEN-1:0] model [NUM_HW_THRDS][CSR_COUNT];
    bit            known [NUM_HW_THRDS][CSR_COUNT];
    bit [isa_pkg::PRIV_MODE_W-1:0] priv [NUM_HW_THRDS];
    bit [isa_pkg::PRIV_MODE_W-1:0] mpp [NUM_HW_THRDS];
    bit mie [NUM_HW_THRDS];
    bit mpie [NUM_HW_THRDS];
    bit spp [NUM_HW_THRDS];
    bit sie [NUM_HW_THRDS];
    bit spie [NUM_HW_THRDS];

    function new(string name = "csr_scb", uvm_component parent = null);
        super.new(name, parent);
        reset_model();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        after_export = new("after_export", this);
        after_fifo   = new("after_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        after_export.connect(after_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        csr_txn txn;
        bit [XLEN-1:0] expected;

        forever begin
            after_fifo.get(txn);
            if (!txn.rst_n) begin
                reset_model();
            end else begin
                apply_transition(txn);
                expected = read_model(txn.thrd_id, txn.rs_addr, txn.irq_timer[txn.thrd_id]);
                if (is_known_read(txn.thrd_id, txn.rs_addr) && txn.rdata !== expected)
                    `uvm_error("CSR_SCB",
                        $sformatf("Read mismatch thrd=%0d csr=%0d expected=0x%016h actual=0x%016h",
                                  txn.thrd_id, txn.rs_addr, expected, txn.rdata))
                if (txn.priv_mode !== priv[txn.thrd_id])
                    `uvm_error("CSR_SCB", "Privilege mode mismatch")
                if (known[txn.thrd_id][CSR_MEDELEG] &&
                    txn.medeleg !== model[txn.thrd_id][CSR_MEDELEG])
                    `uvm_error("CSR_SCB", "MEDELEG output mismatch")
                if (known[txn.thrd_id][CSR_MIDELEG] &&
                    txn.mideleg !== model[txn.thrd_id][CSR_MIDELEG])
                    `uvm_error("CSR_SCB", "MIDELEG output mismatch")
            end
        end
    endtask: run_phase

    function void reset_model();
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            priv[t] = isa_pkg::PRIV_MODE_M;
            mpp[t]  = isa_pkg::PRIV_MODE_M;
            mie[t]  = 1'b0;
            mpie[t] = 1'b0;
            spp[t]  = 1'b0;
            sie[t]  = 1'b0;
            spie[t] = 1'b0;
            for (int c = 0; c < CSR_COUNT; c++)
                known[t][c] = 1'b0;
        end
    endfunction

    function void apply_transition(csr_txn txn);
        int t;

        t = txn.thrd_id;
        if (txn.kind == 1 && txn.trap_to_s) begin
            model[t][CSR_SEPC]   = txn.wdata;
            model[t][CSR_SCAUSE] = txn.wdata ^ 64'h55aa;
            model[t][CSR_STVAL]  = txn.wdata ^ 64'haa55;
            known[t][CSR_SEPC]   = 1'b1;
            known[t][CSR_SCAUSE] = 1'b1;
            known[t][CSR_STVAL]  = 1'b1;
            spp[t]  = priv[t] == isa_pkg::PRIV_MODE_S;
            spie[t] = sie[t];
            sie[t]  = 1'b0;
            priv[t] = isa_pkg::PRIV_MODE_S;
        end else if (txn.kind == 1) begin
            model[t][CSR_MEPC]   = txn.wdata;
            model[t][CSR_MCAUSE] = txn.wdata ^ 64'h55aa;
            known[t][CSR_MEPC]   = 1'b1;
            known[t][CSR_MCAUSE] = 1'b1;
            mpp[t]  = priv[t];
            mpie[t] = mie[t];
            mie[t]  = 1'b0;
            priv[t] = isa_pkg::PRIV_MODE_M;
        end else if (txn.kind == 2) begin
            priv[t] = mpp[t];
            mpp[t]  = isa_pkg::PRIV_MODE_U;
            mie[t]  = mpie[t];
            mpie[t] = 1'b1;
        end else if (txn.kind == 3) begin
            priv[t] = spp[t] ? isa_pkg::PRIV_MODE_S : isa_pkg::PRIV_MODE_U;
            spp[t]  = 1'b0;
            sie[t]  = spie[t];
            spie[t] = 1'b1;
        end else if (txn.kind == 0 && txn.rd_addr == CSR_MSTATUS) begin
            mpp[t]  = isa_pkg::csr_mstatus_mpp(txn.wdata);
            mie[t]  = txn.wdata[isa_pkg::CSR_MSTATUS_MIE_BIT];
            mpie[t] = txn.wdata[isa_pkg::CSR_MSTATUS_MPIE_BIT];
        end else if (txn.kind == 0 && txn.rd_addr == CSR_SSTATUS) begin
            spp[t]  = txn.wdata[isa_pkg::CSR_SSTATUS_SPP_BIT];
            sie[t]  = txn.wdata[isa_pkg::CSR_SSTATUS_SIE_BIT];
            spie[t] = txn.wdata[isa_pkg::CSR_SSTATUS_SPIE_BIT];
        end else if (txn.kind == 0 && !is_read_only(txn.rd_addr)) begin
            model[t][txn.rd_addr] = txn.wdata;
            known[t][txn.rd_addr] = 1'b1;
        end
    endfunction: apply_transition

    function bit [XLEN-1:0] read_model(int t, int addr, bit irq);
        unique case (addr)
            CSR_MSTATUS:   return isa_pkg::csr_mstatus_from_fields(mpp[t], mpie[t], mie[t]);
            CSR_SSTATUS:   return isa_pkg::csr_sstatus_from_fields(spp[t], spie[t], sie[t]);
            CSR_MIP:       return isa_pkg::csr_mip_from_mtip(irq);
            CSR_SIP:       return '0;
            CSR_THREAD_ID: return XLEN'(t);
            default:       return model[t][addr];
        endcase
    endfunction

    function bit is_known_read(int t, int addr);
        return addr inside {CSR_MSTATUS, CSR_SSTATUS, CSR_MIP, CSR_SIP, CSR_THREAD_ID}
            || known[t][addr];
    endfunction

    function bit is_read_only(int addr);
        return addr inside {CSR_MSTATUS, CSR_SSTATUS, CSR_THREAD_ID, CSR_MIP, CSR_SIP};
    endfunction
endclass: csr_scb
