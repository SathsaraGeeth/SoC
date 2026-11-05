/* P11---  */
// property p_rx_state_holds_without_tick;
//     @(posedge clk) disable iff (!rst_n)
//     !dut.w_samp_tick |=> $stable(dut.s_rx_state);
// endproperty: p_rx_state_holds_without_tick

// assert property (p_rx_state_holds_without_tick) else $error("UART RX state changed without a sample tick");

always_ff @(posedge clk) begin: p_rx_state_holds_without_tick
    if (f_past_valid && rst_n && $past(rst_n) && !$past(dut.w_samp_tick)) begin
        assert (dut.s_rx_state == $past(dut.s_rx_state));
    end
end: p_rx_state_holds_without_tick
/*  ---P11 */


/* P12---  */
// property p_rx_serial_valid_requires_tick;
//     @(posedge clk) disable iff (!rst_n)
//     $changed(dut.w_s_rx_data_valid) |-> $past(dut.w_samp_tick);
// endproperty: p_rx_serial_valid_requires_tick

// assert property (p_rx_serial_valid_requires_tick) else $error("UART RX serial valid occurred without a sample tick");

always_ff @(posedge clk) begin: p_rx_serial_valid_requires_tick
    if (f_past_valid && rst_n && $past(rst_n) && dut.w_s_rx_data_valid) begin
        assert ($past(dut.w_samp_tick));
    end
end: p_rx_serial_valid_requires_tick
/*  ---P12 */


/* P13---  */
// property p_rx_parallel_valid_requires_tick;
//     @(posedge clk) disable iff (!rst_n)
//     $changed(dut.w_p_rx_data_valid) |-> $past(dut.w_samp_tick);
// endproperty: p_rx_parallel_valid_requires_tick

// assert property (p_rx_parallel_valid_requires_tick) else $error("UART RX parallel valid occurred without a sample tick");

always_ff @(posedge clk) begin: p_rx_parallel_valid_requires_tick
    if (f_past_valid && rst_n && $past(rst_n) && dut.w_p_rx_data_valid) begin
        assert ($past(dut.w_samp_tick));
    end
end: p_rx_parallel_valid_requires_tick
/*  ---P13 */
