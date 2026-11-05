/* P6---  */
// property tx_idle_is_high;
//     @(posedge clk) disable iff (!rst_n)
//     (dut.s_tx_state == F_TX_IDLE) |-> tx;
// endproperty: tx_idle_is_high

// assert property (tx_idle_is_high) else $error("UART TX is not high while idle");

always_ff @(posedge clk) begin: p_tx_idle_is_high
    if (rst_n && (dut.s_tx_state == F_TX_IDLE)) begin
       assert (tx); 
    end
end: p_tx_idle_is_high
/*  ---P6 */


/* P7---  */
// property tx_start_is_low;
//     @(posedge clk) disable iff (!rst_n)
//     (dut.s_tx_state == F_TX_START) |-> !tx;
// endproperty: tx_start_is_low

// assert property (tx_start_is_low) else $error("UART TX start bit is not low");

always_ff @(posedge clk) begin: p_tx_start_is_low
    if (rst_n && (dut.s_tx_state == F_TX_START)) begin
        assert (!tx);
    end
end: p_tx_start_is_low
/*  ---P7 */


/* P8---  */
// property p_tx_state_holds_without_tick;
//     @(posedge clk) disable iff (!rst_n)
//     !dut.w_baud_tick |=> $stable(dut.s_tx_state);
// endproperty: p_tx_state_holds_without_tick

// assert property (p_tx_state_holds_without_tick) else $error("UART TX state changed without a baud tick");

always_ff @(posedge clk) begin: p_tx_state_holds_without_tick
    if (f_past_valid && rst_n && $past(rst_n) && !$past(dut.w_baud_tick)) begin
        assert (dut.s_tx_state == $past(dut.s_tx_state));
    end
end: p_tx_state_holds_without_tick
/*  ---P8 */
