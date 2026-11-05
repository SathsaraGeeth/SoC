always_ff @(posedge clk) begin: p_fpu_datapath_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (!dut.lane[0].w_s6_valid);
        assert (!dut.lane[1].w_s6_valid);
        assert (!l0_out_valid);
        assert (!l1_out_valid);
        assert (dut.fp_iter.r_state == ITER_IDLE);
    end
end: p_fpu_datapath_reset
