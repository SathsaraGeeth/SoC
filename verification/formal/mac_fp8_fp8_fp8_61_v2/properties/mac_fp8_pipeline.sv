always_comb begin: p_mac_fp8_done_composition
    assert (done == ((dut.r_done_pipe[1] && !dut.r_done_single_pipe[1])
                  || (dut.r_done_pipe[2] && dut.r_done_single_pipe[2])));
end: p_mac_fp8_done_composition

always_ff @(posedge clk) begin: p_mac_fp8_pipeline
    if (rst_n && clr_n && f_past_valid && $past(rst_n && clr_n)) begin
        if ($past(done))
            assert (d == $past(dut.w_s6_res));
        else
            assert (d == $past(d));

        if ($past(en)) begin
            assert (dut.r_last_pipe == {$past(dut.r_last_pipe[10:0]), $past(last)});
            assert (dut.r_done_pipe == {$past(dut.r_done_pipe[1:0]), $past(dut.w_acc_done)});
            assert (dut.w_s2_ab_sgn == ($past(a[7]) ^ $past(b[7])));
            assert (dut.w_s2_ab_mul_man ==
                    (8'($past(dut.w_s1_a_man_ext)) * 8'($past(dut.w_s1_b_man_ext))));
        end else begin
            assert (dut.r_last_pipe == $past(dut.r_last_pipe));
            assert (dut.r_done_pipe == $past(dut.r_done_pipe));
        end
    end
end: p_mac_fp8_pipeline
