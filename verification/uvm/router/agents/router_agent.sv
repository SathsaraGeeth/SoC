/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_agent extends uvm_agent;
    `uvm_component_utils(router_agent)

    router_seqr seqr;
    router_drv drv;
    router_mon mon;
    uvm_analysis_port #(router_txn) before_ap;
    uvm_analysis_port #(router_txn) after_ap;

    function new(string name = "router_agent", uvm_component parent = null);
        super.new(name, parent);
        before_ap = new("before_ap", this);
        after_ap = new("after_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = router_seqr::type_id::create("seqr", this);
        drv = router_drv::type_id::create("drv", this);
        mon = router_mon::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        drv.before_ap.connect(before_ap);
        mon.after_ap.connect(after_ap);
    endfunction
endclass: router_agent
