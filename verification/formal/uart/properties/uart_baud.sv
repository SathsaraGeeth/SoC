/* P14---  */
// property p_baud_tick_matches_divisor;
//     @(posedge clk)
//     disable iff (!f_past_valid || !rst_n || !$past(rst_n))
//     dut.w_baud_tick == ($past(dut.r_baud_ctr) == ($past(baud_div) - 1'b1));
// endproperty: p_baud_tick_matches_divisor

// assert property (p_baud_tick_matches_divisor) else $error("UART baud tick does not match baud divisor");

always_ff @(posedge clk) begin: p_baud_tick_matches_divisor
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if ($past(dut.w_div_update_safe && (dut.r_baud_div != dut.r_baud_div_pend)))
            assert (!dut.w_baud_tick);
        else
            assert (dut.w_baud_tick ==
                    ($past(dut.r_baud_ctr) == ($past(dut.r_baud_div) - 1'b1)));
    end
end: p_baud_tick_matches_divisor
/*  ---P14 */


/* P15---  */
// property p_sample_tick_matches_divisor;
//     @(posedge clk)
//     disable iff (!f_past_valid || !rst_n || !$past(rst_n))
//     dut.w_samp_tick == ($past(dut.r_samp_ctr) == (($past(baud_div) / 16) - 1'b1));
// endproperty: p_sample_tick_matches_divisor

// assert property (sample_tick_matches_divisor) else $error("UART sample tick does not match baud divisor");

always_ff @(posedge clk) begin: p_sample_tick_matches_divisor
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if ($past(dut.w_div_update_safe && (dut.r_baud_div != dut.r_baud_div_pend)))
            assert (!dut.w_samp_tick);
        else
            assert (dut.w_samp_tick ==
                    ($past(dut.r_samp_ctr) == (($past(dut.r_baud_div) / 16) - 1'b1)));
    end
end: p_sample_tick_matches_divisor
/*  ---P15 */
