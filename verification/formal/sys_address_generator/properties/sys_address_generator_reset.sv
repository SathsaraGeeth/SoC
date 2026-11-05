always_ff @(posedge clk) begin: p_sys_address_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (dut.r_state == 1'b0);
        assert (!addr_valid);
        assert (!done);
        assert (dut.r_a_idx == '0);
        assert (dut.r_b_idx == '0);
        assert (dut.r_q_idx == '0);
        assert (dut.r_beat == '0);
    end
end: p_sys_address_reset
