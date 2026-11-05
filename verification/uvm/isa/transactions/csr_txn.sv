/* 
 * verification/uvm/isa/csr_txn.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. need to be inorder
 */

`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;

class csr_txn extends txn;
    `uvm_object_utils(csr_txn)

    logic [$clog2(core_pkg::CSR_COUNT)-1:0] waddr;
    logic [core_pkg::XLEN-1:0]              wdata;

    function new(string name = "csr_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[CSR COMMIT] ID: %0d, Thread: %0d, PC: 0x%h, CSR Addr: 0x%h, Data: 0x%h", 
                         commit_id, thrd_id, pc, waddr, wdata);
    endfunction
endclass: csr_txn
