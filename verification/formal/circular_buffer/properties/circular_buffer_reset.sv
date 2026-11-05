/* P1---  */
// property p_reset_state;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (!rst_n || !clr_n) |=> empty && !full && !deq_ready &&
//                            (level == '0) && (dut.r_head_ptr == '0) &&
//                            (dut.r_tail_ptr == '0);
// endproperty: p_reset_state

// assert property (p_reset_state) else $error("Circular buffer reset state mismatch");

always_ff @(posedge clk) begin: p_reset_state
    if (f_past_valid && (!$past(rst_n) || !$past(clr_n))) begin
        assert (empty);
        assert (!full);
        assert (!deq_ready);
        assert (level == '0);
        assert (dut.r_head_ptr == '0);
        assert (dut.r_tail_ptr == '0);
    end
end: p_reset_state
/*  ---P1 */
