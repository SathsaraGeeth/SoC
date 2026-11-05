always_ff @(posedge clk) begin: p_mmacu_reset
    if(f_past_valid && !$past(rst_n)) begin
        assert(!dut.r_flushing); assert(dut.r_flush_ctr=='0);
        assert(!d_valid); assert(d=='0); assert(dut.r_done_row=='0);
        assert(dut.wn_valid[0][0]==1'b0); assert(dut.wn_valid[1][1]==1'b0);
    end
end: p_mmacu_reset

