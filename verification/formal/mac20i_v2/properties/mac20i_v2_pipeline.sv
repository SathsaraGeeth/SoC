always_ff @(posedge clk) begin: p_mac20i_pipeline
    if (rst_n && clr_n && f_past_valid && $past(rst_n && clr_n)) begin
        if ($past(en)) begin
            assert (done == $past(dut.r_last_pipe[3]));
            assert (dut.r_last_pipe == {$past(dut.r_last_pipe[2:0]), $past(last)});
            assert (dut.w_mul_res == 16'($signed($past(a)) * $signed($past(b))));
            if ($past(done))
                assert (d == $past(dut.w_s2_d[7:0]));
        end else begin
            assert (done == $past(done));
            assert (d == $past(d));
            assert (dut.r_last_pipe == $past(dut.r_last_pipe));
            assert (dut.w_mul_res == $past(dut.w_mul_res));
        end
    end
end: p_mac20i_pipeline
