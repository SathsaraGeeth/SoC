/* P5---  */
// property p_fifo_ready_status;
//     @(posedge clk) disable iff (!rst_n)
//     (enq_tx_ready == !tx_full) && (deq_rx_ready == !rx_empty);
// endproperty: p_fifo_ready_status

// assert property (p_fifo_ready_status) else $error("UART FIFO ready/status mismatch");

always_ff @(posedge clk) begin: p_ready_status
    if (rst_n) begin
        assert (enq_tx_ready == !tx_full);
        assert (deq_rx_ready == !rx_empty);
    end
end
/*  ---P5 */
