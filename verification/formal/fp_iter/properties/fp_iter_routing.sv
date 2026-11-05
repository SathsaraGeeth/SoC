always_comb begin: p_fp_iter_ready_ownership
    assert (l0_in_ready == !(l0_op inside {DIV, SQRT}));
    assert (l1_in_ready == (dut.r_state == ITER_IDLE));
    assert (iter_owns_p0 == p0_in_valid);
    assert (iter_owns_p1 == ((dut.r_state != ITER_IDLE)
                          || (l1_in_valid && (l1_op inside {DIV, SQRT}))));
end: p_fp_iter_ready_ownership

always_comb begin: p_fp_iter_bypass
    if (p0_out_valid && p0_out_thrd[XLEN-1:4] != '1) begin
        assert (l0_out_valid);
        assert (l0_out_thrd == p0_out_thrd);
        assert (l0_result == p0_result);
    end
    if (dut.r_state != ITER_DONE && p1_out_valid
     && p1_out_thrd[XLEN-1:4] != '1) begin
        assert (l1_out_valid);
        assert (l1_out_thrd == p1_out_thrd);
        assert (l1_result == p1_result);
    end
    if (p0_out_valid && p0_out_thrd[XLEN-1:4] == '1)
        assert (!l0_out_valid);
end: p_fp_iter_bypass
