/* P9---  */
// property p_tx_idle_transition;
//     @(posedge clk) disable iff (!rst_n)
//     (dut.w_baud_tick && (dut.s_tx_state == F_TX_IDLE)) |=>
//     (dut.s_tx_state == ($past(dut.w_valid_tx) ? F_TX_START : F_TX_IDLE));
// endproperty: p_tx_idle_transition

// assert property (p_tx_idle_transition) else $error("UART TX IDLE transition is incorrect");

always_ff @(posedge clk) begin: p_tx_idle_transition
    if (f_past_valid && rst_n && $past(rst_n) && $past(dut.w_baud_tick)
        && ($past(dut.s_tx_state) == F_TX_IDLE)) begin
        if ($past(dut.w_valid_tx)) begin
            assert (dut.s_tx_state == F_TX_START);
        end else begin
            assert (dut.s_tx_state == F_TX_IDLE);
        end
    end
end: p_tx_idle_transition
/*  ---P9 */


/* P10---  */
// property p_tx_start_to_data0;
//     @(posedge clk) disable iff (!rst_n)
//     (dut.w_baud_tick && (dut.s_tx_state == F_TX_START)) |=>
//     (dut.s_tx_state == F_TX_D0);
// endproperty: p_tx_start_to_data0

// assert property (p_tx_start_to_data0) else $error("UART TX START did not advance to D0");

always_ff @(posedge clk) begin: p_tx_start_to_data0
    if (f_past_valid && rst_n && $past(rst_n) &&
        $past(dut.w_baud_tick) && ($past(dut.s_tx_state) == F_TX_START)) begin
        assert (dut.s_tx_state == F_TX_D0);
    end
end: p_tx_start_to_data0
/*  ---P10 */
