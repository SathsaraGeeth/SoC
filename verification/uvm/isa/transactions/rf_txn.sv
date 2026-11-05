/*
 * Comments:
 * 1. need to be inorder
 */

`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;

class rf_txn extends txn;
    `uvm_object_utils(rf_txn)

    logic [$clog2(core_pkg::REG_COUNT)-1:0] waddr;
    logic [core_pkg::XLEN-1:0]              wdata;

    function new(string name = "rf_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[RF COMMIT] ID: %0d, Thread: %0d, PC: 0x%h, Register: x%0d, Data: 0x%h", 
                         commit_id, thrd_id, pc, waddr, wdata);
    endfunction

endclass: rf_txn
