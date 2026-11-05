/* SPDX-License-Identifier: Apache-2.0 */
import uvm_pkg::*; `include "uvm_macros.svh"
class mmacu_core_v2_drv extends uvm_driver #(mmacu_core_v2_txn);
    `uvm_component_utils(mmacu_core_v2_drv)
    virtual mmacu_core_v2_if vif;
    function new(string name="mmacu_core_v2_drv", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mmacu_core_v2_if)::get(this,"","vif",vif))
            `uvm_fatal("MMACU_DRV", "Virtual interface not set")
    endfunction
    task run_phase(uvm_phase phase);
        mmacu_core_v2_txn txn;
        int unsigned input_wait;
        wait(vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(txn);
            for (int beat=0; beat<8; beat++) begin
                @(negedge vif.clk);
                for (int lane=0; lane<8; lane++) begin
                    vif.a[lane*8 +: 8] <= txn.a[lane];
                    vif.b[lane*8 +: 8] <= txn.b[lane];
                end
                vif.start    <= beat == 0;
                vif.last     <= beat == 0;
                vif.end_tile <= beat == 7;
                vif.a_valid  <= 1'b1;
                vif.b_valid  <= 1'b1;
                input_wait = 0;
                do begin
                    @(posedge vif.clk);
                    input_wait++;
                    if (input_wait == 100)
                        `uvm_fatal("MMACU_DRV",
                            $sformatf("Input timeout beat=%0d a_ready=%b b_ready=%b flushing=%b",
                                      beat, vif.a_ready, vif.b_ready,
                                      $root.mmacu_core_v2_tb_top.dut.r_flushing))
                end while (!(vif.a_ready && vif.b_ready));
                vif.a_valid <= 1'b0; vif.b_valid <= 1'b0;
                vif.start <= 1'b0; vif.last <= 1'b0; vif.end_tile <= 1'b0;
            end
            repeat (txn.output_stall) begin @(negedge vif.clk); vif.d_ready <= 1'b0; end
            vif.d_ready <= 1'b1;
            for (int row=0; row<8; row++) begin
                int unsigned cycles=0;
                while (!vif.d_valid) begin
                    @(negedge vif.clk); cycles++;
                    if (cycles == 200) `uvm_fatal("MMACU_DRV", "Result timeout")
                end
                @(negedge vif.clk);
            end
            vif.d_ready <= 1'b0;
            seq_item_port.item_done();
        end
    endtask
endclass: mmacu_core_v2_drv
