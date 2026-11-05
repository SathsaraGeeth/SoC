/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;`include "uvm_macros.svh"
class sys_core_test extends uvm_test;`uvm_component_utils(sys_core_test)sys_core_env u_env;function new(string name="sys_core_test",uvm_component parent=null);super.new(name,parent);endfunction
function void build_phase(uvm_phase p);super.build_phase(p);u_env=sys_core_env::type_id::create("u_env",this);endfunction task run_phase(uvm_phase p);sys_core_seq s;p.raise_objection(this);s=sys_core_seq::type_id::create("seq");s.start(u_env.u_agent.seqr);repeat(8)@(posedge u_env.u_agent.drv.vif.clk);p.drop_objection(this);endtask endclass

