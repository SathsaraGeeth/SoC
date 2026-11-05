/* P8--- outbound page messages remain stable while backpressured. */
always_ff @(posedge i_clk) begin: p_page_message_stability
    if (f_past_valid && i_rst_n && $past(i_rst_n) &&
        $past(o_page_msg_valid && !i_page_msg_ready)) begin
        assert (o_page_msg_valid);
        assert (o_page_msg == $past(o_page_msg));
    end
end: p_page_message_stability
/*  ---P8 */
