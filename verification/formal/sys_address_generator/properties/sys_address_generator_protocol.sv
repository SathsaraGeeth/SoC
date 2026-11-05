always_ff @(posedge clk) begin: p_sys_address_protocol
    if (rst_n && dut.r_state == 1'b1) begin
        assert (dut.r_a_tiles_limit inside {[1:2]});
        assert (dut.r_b_tiles_limit inside {[1:2]});
        assert (dut.r_r_tiles_limit inside {[1:2]});
        assert (dut.r_a_idx < dut.r_a_tiles_limit);
        assert (dut.r_b_idx < dut.r_b_tiles_limit);
        assert (dut.r_q_idx < dut.r_r_tiles_limit);
        assert (dut.r_beat < M);
    end
    if (rst_n && f_past_valid && $past(rst_n && addr_valid && !addr_ready)) begin
        assert (addr_valid);
        assert (addr_data == $past(addr_data));
        assert (dut.r_a_idx == $past(dut.r_a_idx));
        assert (dut.r_b_idx == $past(dut.r_b_idx));
        assert (dut.r_q_idx == $past(dut.r_q_idx));
        assert (dut.r_beat == $past(dut.r_beat));
    end
    if (rst_n && f_past_valid && $past(done))
        assert (!done);
end: p_sys_address_protocol
