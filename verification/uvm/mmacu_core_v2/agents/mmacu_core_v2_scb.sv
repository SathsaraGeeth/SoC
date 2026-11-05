/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_scb extends uvm_scoreboard;
    `uvm_component_utils(mmacu_core_v2_scb)
    uvm_analysis_export #(mmacu_core_v2_txn) after_export;
    uvm_tlm_analysis_fifo #(mmacu_core_v2_txn) after_fifo;
    longint signed accum[8][8];
    bit [63:0] expected_rows[$];
    function new(string name="mmacu_core_v2_scb",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);after_export=new("after_export",this);after_fifo=new("after_fifo",this);endfunction
    function void connect_phase(uvm_phase phase);after_export.connect(after_fifo.analysis_export);endfunction
    task run_phase(uvm_phase phase);
        mmacu_core_v2_txn txn; bit [63:0] row; longint signed product;
        forever begin
            after_fifo.get(txn);
            if (!txn.output_event) begin
                if (txn.start) foreach(accum[i,j]) accum[i][j]=0;
                foreach(accum[i,j]) begin product=$signed(txn.a[i])*$signed(txn.b[j]); accum[i][j]+=product; end
                if (txn.end_tile) for(int i=0;i<8;i++) begin
                    row='0; for(int j=0;j<8;j++) row[j*8+:8]=accum[i][j][7:0]; expected_rows.push_back(row);
                end
            end else if (expected_rows.size()==0) begin
                `uvm_error("MMACU_SCB", "Unexpected result row")
            end else begin
                row=expected_rows.pop_front();
                if(txn.d!==row) `uvm_error("MMACU_SCB",$sformatf("Result mismatch expected=%016h actual=%016h",row,txn.d))
            end
        end
    endtask
endclass: mmacu_core_v2_scb

