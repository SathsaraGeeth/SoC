always_ff @(posedge clk) begin: p_fp_iter_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (dut.r_state == ITER_IDLE);
        assert (!p0_in_valid);
        assert (!p1_in_valid);
        assert (l1_in_ready);
    end
end: p_fp_iter_reset
