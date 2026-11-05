always_comb begin: p_fpu_ready
    assert (req_ready == (!dut.r_busy && !dut.r_result_valid));
    assert (res_valid == dut.r_result_valid);
end: p_fpu_ready

always_ff @(posedge clk) begin: p_fpu_hold
    if (rst_n) begin
        assert (!(dut.r_busy && dut.r_result_valid));
        if (!dut.r_busy)
            assert (!dut.w_dp_result_valid);
    end
    if (rst_n && f_past_valid && $past(rst_n && res_valid && !res_ready)) begin
        assert (res_valid);
        assert (result == $past(result));
        assert (res_thrd_id == $past(res_thrd_id));
    end
    if (rst_n && f_past_valid && $past(rst_n && res_valid && res_ready))
        assert (!res_valid);
end: p_fpu_hold
