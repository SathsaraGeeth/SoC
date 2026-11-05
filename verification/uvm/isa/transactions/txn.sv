`include "uvm_macros.svh"
import uvm_pkg::*;
import core_pkg::*;

virtual class txn extends uvm_sequence_item;

    int unsigned               thrd_id;
    logic [core_pkg::XLEN-1:0] pc;
    
    int unsigned               commit_id;         /* a global id */

    function new(string name = "txn");
        super.new(name);
    endfunction
    
    pure virtual function string convert2string();

endclass: txn
