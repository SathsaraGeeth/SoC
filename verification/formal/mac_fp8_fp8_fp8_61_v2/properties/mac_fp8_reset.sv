always_ff @(posedge clk) begin: p_mac_fp8_reset
    if (f_past_valid && (!$past(rst_n) || !$past(clr_n))) begin
        assert (!done);
        assert (d == '0);
        assert (dut.r_last_pipe == '0);
        assert (dut.r_done_pipe == '0);
        assert (dut.r_done_single_pipe == '0);
        assert (dut.r_done_bank_count == '0);
    end
end: p_mac_fp8_reset
