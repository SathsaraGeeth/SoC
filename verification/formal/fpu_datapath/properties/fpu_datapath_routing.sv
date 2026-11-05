always_comb begin: p_fpu_datapath_lane_eligibility
    assert (l0_in_ready == !(l0_op inside {DIV, SQRT}));
    assert (l1_in_ready == (dut.fp_iter.r_state == ITER_IDLE));
    assert (dut.w_p0_out_valid == dut.lane[0].w_s6_valid);
    assert (dut.w_p1_out_valid == dut.lane[1].w_s6_valid);
    assert (dut.w_p0_out_thrd == dut.lane[0].w_s6_thrd);
    assert (dut.w_p1_out_thrd == dut.lane[1].w_s6_thrd);
end: p_fpu_datapath_lane_eligibility

always_ff @(posedge clk) begin: p_fpu_datapath_metadata
    if (rst_n && l0_out_valid) begin
        assert (l0_out_thrd == dut.w_p0_out_thrd);
        assert (l0_result == dut.w_p0_result);
        assert (dut.w_p0_out_thrd[XLEN-1:4] != '1);
    end
    if (rst_n && l1_out_valid && dut.fp_iter.r_state != ITER_DONE) begin
        assert (l1_out_thrd == dut.w_p1_out_thrd);
        assert (l1_result == dut.w_p1_result);
        assert (dut.w_p1_out_thrd[XLEN-1:4] != '1);
    end
end: p_fpu_datapath_metadata
