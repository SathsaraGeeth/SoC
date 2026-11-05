/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;`include "uvm_macros.svh"
class sys_core_cov extends uvm_subscriber#(sys_core_txn);`uvm_component_utils(sys_core_cov)bit response;bit[7:0]offset;bit[2:0]host;covergroup cg;coverpoint response;coverpoint offset;coverpoint host;endgroup
function new(string name="sys_core_cov",uvm_component parent=null);super.new(name,parent);cg=new();endfunction function void write(sys_core_txn t);response=t.response;offset=t.offset;host=t.host;cg.sample();endfunction endclass

