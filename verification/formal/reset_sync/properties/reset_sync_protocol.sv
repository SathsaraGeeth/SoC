/* P3--- release advances one stage per rising edge. */
always_ff @(posedge clk) begin: p_release_shift
    if (f_past_valid && async_rst_n && $past(async_rst_n)) begin
        assert (dut.reset_ff == {$past(dut.reset_ff[STAGES-2:0]), 1'b1});
    end
end: p_release_shift
/*  ---P3 */

/* P4--- a released reset cannot fall unless asynchronous reset is asserted. */
always_ff @(posedge clk) begin: p_release_is_monotonic
    if (f_past_valid && async_rst_n && $past(async_rst_n) && $past(rst_n)) begin
        assert (rst_n);
    end
end: p_release_is_monotonic
/*  ---P4 */
