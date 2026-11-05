/* P1: Reset clears every sequential helper. */
always_ff @(posedge clk) begin
    if (f_past_valid && $past(!rst_n)) begin
        assert (reg_out == '0);
        assert (pipe_out == '0);
        assert (mul_out == '0);
        assert (add_out == '0);
        assert (u_ctr.r_count == '0);
    end
end
