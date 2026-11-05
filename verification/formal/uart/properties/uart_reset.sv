/* P1---  */
// property p_reset_state;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     !rst_n |=> ((dut.s_tx_state == '0) && (dut.s_rx_state == '0) &&
//                 (tx == 1'b1) && tx_empty && rx_empty &&
//                 (tx_level == '0) && (rx_level == '0));
// endproperty: p_reset_state

// assert property (p_reset_state) else $error("UART reset state mismatch");

always_ff @(posedge clk) begin: p_reset_state
    if (f_past_valid && !$past(rst_n)) begin
        assert (dut.s_tx_state == '0);
        assert (dut.s_rx_state == '0);
        assert (tx);
        assert (tx_empty && rx_empty);
        assert (tx_level == '0);
        assert (rx_level == '0);
    end
end: p_reset_state
/*  ---P1 */