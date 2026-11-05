/*
 * Comments:
 * 1. need to be inorder - because the commits
 *    must retier inorder (even if OOO/weak mm)
 */


`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;

class pc_txn extends txn;
    `uvm_object_utils(pc_txn)

    function new(string name = "pc_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[PC COMMIT] ID: %0d, Thread: %0d, PC: 0x%h", commit_id, thrd_id, pc);
    endfunction
endclass: pc_txn
