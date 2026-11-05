always_comb begin: p_mmacu_comb
    assert(dut.w_gstall_n == !(d_valid && !d_ready));
    if(!dut.r_flushing) begin
        assert(a_ready == (dut.w_ab_ready && a_valid && b_valid));
        assert(b_ready == (dut.w_ab_ready && a_valid && b_valid));
    end
end: p_mmacu_comb

always_ff @(posedge clk) begin: p_mmacu_seq
    if(f_past_valid && rst_n && $past(rst_n)) begin
        if($past(d_valid && !d_ready)) begin
            assert(d_valid); assert(d==$past(d));
            assert(dut.r_flush_ctr==$past(dut.r_flush_ctr));
            assert(dut.r_done_row==$past(dut.r_done_row));
        end
        if($past(dut.w_ab_en && !dut.r_flushing && end_tile)) begin
            assert(dut.r_flushing); assert(dut.r_flush_ctr=='0);
        end
        if($past(dut.r_flushing && dut.w_gstall_n &&
                 dut.r_flush_ctr != dut.r_flush_cycles-1'b1))
            assert(dut.r_flush_ctr==$past(dut.r_flush_ctr)+1'b1);
        if($past(dut.r_flushing && dut.w_gstall_n &&
                 dut.r_flush_ctr == dut.r_flush_cycles-1'b1)) begin
            assert(!dut.r_flushing); assert(dut.r_flush_ctr=='0);
        end
        if($past(!dut.r_flushing && !end_tile))
            assert(!dut.r_flushing);
    end
end: p_mmacu_seq

