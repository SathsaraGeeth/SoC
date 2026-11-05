/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_env extends uvm_env;
    `uvm_component_utils(mmacu_core_v2_env)
    mmacu_core_v2_agent u_agent; mmacu_core_v2_scb u_scb; mmacu_core_v2_cov u_cov;
    function new(string name="mmacu_core_v2_env",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);u_agent=mmacu_core_v2_agent::type_id::create("u_agent",this);u_scb=mmacu_core_v2_scb::type_id::create("u_scb",this);u_cov=mmacu_core_v2_cov::type_id::create("u_cov",this);endfunction
    function void connect_phase(uvm_phase phase);u_agent.after_ap.connect(u_scb.after_export);u_agent.after_ap.connect(u_cov.analysis_export);endfunction
endclass: mmacu_core_v2_env

