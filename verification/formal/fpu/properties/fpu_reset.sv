always_ff @(posedge clk) begin: p_fpu_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (!dut.r_busy);
        assert (!res_valid);
        assert (req_ready);
        assert (result == '0);
        assert (res_thrd_id == '0);
    end
end: p_fpu_reset
