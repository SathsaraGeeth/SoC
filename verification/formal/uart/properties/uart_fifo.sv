/* P2---  */
// property p_fifo_empty_flags;
//     @(posedge clk) disable iff (!rst_n)
//     (tx_empty == (tx_level == '0)) && (rx_empty == (rx_level == '0));
// endproperty: p_fifo_empty_flags

// assert property (p_fifo_empty_flags) else $error("UART FIFO empty flag/level mismatch");

always_ff @(posedge clk) begin: p_fifo_empty_flags
    if (rst_n) begin
        assert (tx_empty == (tx_level == '0));
        assert (rx_empty == (rx_level == '0));
    end
end: p_fifo_empty_flags
/*  ---P2 */


/* P3---  */
// property p_fifo_full_flags;
//     @(posedge clk) disable iff (!rst_n)
//     (tx_full == (tx_level == TX_DEPTH)) && (rx_full == (rx_level == RX_DEPTH));
// endproperty: p_fifo_full_flags

// assert property (p_fifo_full_flags) else $error("UART FIFO full flag/level mismatch");

always_ff @(posedge clk) begin: p_fifo_full_flags
    if (rst_n) begin
        assert (tx_full == (tx_level == $bits(tx_level)'(TX_DEPTH)));
        assert (rx_full == (rx_level == $bits(rx_level)'(RX_DEPTH)));
    end
end: p_fifo_full_flags
/*  ---P3 */


/* P4---  */
// property p_fifo_levels_in_bounds;
//     @(posedge clk) disable iff (!rst_n)
//     (tx_level <= TX_DEPTH) && (rx_level <= RX_DEPTH);
// endproperty: p_fifo_levels_in_bounds

// assert property (p_fifo_levels_in_bounds) else $error("UART FIFO level exceeded its configured depth");

always_ff @(posedge clk) begin: p_fifo_levels_in_bounds
    if (rst_n) begin
        assert (tx_level <= $bits(tx_level)'(TX_DEPTH));
        assert (rx_level <= $bits(rx_level)'(RX_DEPTH));
    end
end: p_fifo_levels_in_bounds
/*  ---P4 */
