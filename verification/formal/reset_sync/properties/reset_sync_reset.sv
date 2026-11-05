/* P1--- asynchronous reset clears every synchronizer stage. */
always_ff @(posedge clk) begin: p_reset_clears_pipeline
    if (f_past_valid && !$past(async_rst_n)) begin
        assert (dut.reset_ff == '0);
        assert (!rst_n);
    end
end: p_reset_clears_pipeline
/*  ---P1 */

/* P2--- the output is exactly the final synchronizer stage. */
always_comb begin: p_output_is_last_stage
    assert (rst_n == dut.reset_ff[STAGES-1]);
end: p_output_is_last_stage
/*  ---P2 */
