/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class sys_core_seq extends uvm_sequence #(sys_core_txn);
    `uvm_object_utils(sys_core_seq)
    function new(string name="sys_core_seq");super.new(name);endfunction
    task send(bit[7:0] off,bit[63:0] data,bit[7:0] mask,bit[2:0] host,int idle=0,int bp=0);
      sys_core_txn t=sys_core_txn::type_id::create("txn");start_item(t);t.offset=off;t.data=data;t.mask=mask;t.host=host;t.idle_cycles=idle;t.backpressure=bp;finish_item(t);
    endtask
    task command(bit[7:0] kind,bit[63:0] vtid,bit[63:0] tid,bit[2:0] host);
      send(8'h08,{32'b0,kind,24'b0},8'hff,host);
      send(8'h08,vtid,8'hff,host); send(8'h08,tid,8'hff,host); send(8'h08,'0,8'hff,host,3,2);
    endtask
    virtual task body();
      send(8'h00,'0,'0,0); send(8'h10,'0,'0,0);
      command(8'h03,64'h55,64'd2,2);
      send(8'h00,'0,'0,2,2,2);
      command(8'h04,'0,'0,2);
      send(8'h00,'0,'0,2,3,1);
      repeat(80) begin sys_core_txn t=sys_core_txn::type_id::create("txn");start_item(t);assert(t.randomize() with {offset!=8'h08;mask==0;host==2;}) else `uvm_error("SYS_SEQ","Randomization failed") finish_item(t);end
    endtask
endclass: sys_core_seq
