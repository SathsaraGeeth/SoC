/* P1: Reset returns timer state and response state to defaults. */
always_ff @(posedge clk) begin: p_timer_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (dut.mtime_q == 64'd0);
        assert (dut.mtimecmp_q == 64'hffff_ffff_ffff_ffff);
        assert (!resp_valid);
        assert (resp_rdata == 64'd0);
    end
end: p_timer_reset

