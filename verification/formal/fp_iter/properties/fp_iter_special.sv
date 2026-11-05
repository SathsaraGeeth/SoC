always_ff @(posedge clk) begin: p_fp_iter_special
    if (rst_n && f_past_valid && $past(rst_n && l1_in_valid && l1_in_ready
     && l1_op == DIV && l1_a == 64'h0000_0000_3f80_0000
     && l1_b[31:0] == 32'h0000_0000)) begin
        assert (dut.r_state == ITER_DONE);
        assert (l1_out_valid);
        assert (l1_out_thrd == $past(l1_in_thrd));
        assert (l1_result == 64'h0000_0000_7f80_0000);
    end
    if (rst_n && f_past_valid && $past(rst_n && l1_in_valid && l1_in_ready
     && l1_op == SQRT && l1_a[31:0] == 32'hbf80_0000)) begin
        assert (dut.r_state == ITER_DONE);
        assert (l1_out_valid);
        assert (l1_out_thrd == $past(l1_in_thrd));
        assert (l1_result == 64'h0000_0000_7fc0_0000);
    end
end: p_fp_iter_special
