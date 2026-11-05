`include "uvm_macros.svh"

import uvm_pkg::*;
import core_pkg::*;

class coverage extends uvm_subscriber #(txn);
    `uvm_component_utils(coverage)

    logic [$clog2(core_pkg::REG_COUNT)-1:0]  cv_rf_addr;
    logic [isa_pkg::CSR_ADDR_W-1:0]          cv_csr_addr;

    covergroup cg_rf_commit;
        option.per_instance = 1;
        cp_rf_addr: coverpoint cv_rf_addr {
            bins regs[] = {[0:31]};
        }
    endgroup

    covergroup cg_csr_commit;
        option.per_instance = 1;
        cp_csr_addr: coverpoint cv_csr_addr {
            bins csrs[16] = {[0:4095]};
        }
    endgroup

    function new(string name = "coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_rf_commit = new();
        cg_csr_commit = new();
    endfunction

    virtual function void write(txn t);
        rf_txn rf_txn;
        csr_txn csr_txn;

        if ($cast(rf_txn, t)) begin
            cv_rf_addr = rf_txn.waddr;
            cg_rf_commit.sample();
        end
        else if ($cast(csr_txn, t)) begin
            cv_csr_addr = csr_txn.waddr;
            cg_csr_commit.sample();
        end
    endfunction

endclass: coverage
