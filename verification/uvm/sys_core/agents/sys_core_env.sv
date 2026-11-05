/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*;`include "uvm_macros.svh"
class sys_core_env extends uvm_env;`uvm_component_utils(sys_core_env)sys_core_agent u_agent;sys_core_scb u_scb;sys_core_cov u_cov;
function new(string name="sys_core_env",uvm_component parent=null);super.new(name,parent);endfunction
function void build_phase(uvm_phase p);super.build_phase(p);u_agent=sys_core_agent::type_id::create("u_agent",this);u_scb=sys_core_scb::type_id::create("u_scb",this);u_cov=sys_core_cov::type_id::create("u_cov",this);endfunction
function void connect_phase(uvm_phase p);u_agent.after_ap.connect(u_scb.after_export);u_agent.after_ap.connect(u_cov.analysis_export);endfunction endclass

