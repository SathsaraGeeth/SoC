/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_mon extends uvm_monitor;
    `uvm_component_utils(mmacu_core_v2_mon)
    virtual mmacu_core_v2_if vif;
    uvm_analysis_port #(mmacu_core_v2_txn) after_ap;
    logic stalled; logic [63:0] stalled_d;
    function new(string name="mmacu_core_v2_mon", uvm_component parent=null);
        super.new(name,parent); after_ap=new("after_ap",this);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mmacu_core_v2_if)::get(this,"","vif",vif))
            `uvm_fatal("MMACU_MON", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        mmacu_core_v2_txn txn;
        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) stalled=0;
            else begin
                if (stalled && (!vif.d_valid || vif.d !== stalled_d))
                    `uvm_error("MMACU_MON", "Backpressured result changed")
                stalled=vif.d_valid && !vif.d_ready; stalled_d=vif.d;
                if (vif.a_valid && vif.b_valid && vif.a_ready && vif.b_ready) begin
                    txn=mmacu_core_v2_txn::type_id::create("input");
                    for(int i=0;i<8;i++) begin txn.a[i]=vif.a[i*8+:8]; txn.b[i]=vif.b[i*8+:8]; end
                    txn.start=vif.start; txn.end_tile=vif.end_tile; after_ap.write(txn);
                end
                if (vif.d_valid && vif.d_ready) begin
                    txn=mmacu_core_v2_txn::type_id::create("output");
                    txn.output_event=1; txn.d=vif.d; after_ap.write(txn);
                end
            end
        end
    endtask
endclass: mmacu_core_v2_mon

