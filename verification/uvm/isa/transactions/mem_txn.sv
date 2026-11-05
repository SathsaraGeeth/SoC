/*
 * Comments:
 * 1. Don't need to be inorder - as the isa defined is
 *    a weak memory
 */


`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;

class mem_txn extends txn;
    `uvm_object_utils(mem_txn)

    logic [core_pkg::VIR_ADDR_W-1:0] waddr;
    logic [core_pkg::XLEN-1:0] wdata;
    logic [core_pkg::XLEN-1:0] wmask;

    function new(string name = "mem_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[MEM COMMIT] ID: %0d, Thread: %0d, PC: 0x%h, Address: 0x%h, Data: 0x%h, Mask: 0x%h",
                         commit_id, thrd_id, pc, waddr, wdata, wmask);
    endfunction
endclass: mem_txn
