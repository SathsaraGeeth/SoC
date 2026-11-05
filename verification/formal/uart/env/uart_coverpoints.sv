/* C1---  */
// property p_reset_release;
//     @(posedge clk)
//     rst_n && tx_empty && rx_empty && (dut.s_tx_state == F_TX_IDLE);
// endproperty: p_reset_release

// cp_reset_release:
// cover property (p_reset_release) else $info("UART reset release not covered");

always_ff @(posedge clk) begin: c_reset_release
    cover (rst_n && tx_empty && rx_empty && (dut.s_tx_state == F_TX_IDLE));
end: c_reset_release
/*  ---C1 */


/* C2---  */
// property p_tx_enqueue;
//     @(posedge clk)
//     rst_n && enq_tx_valid && enq_tx_ready;
// endproperty: p_tx_enqueue

// cp_tx_enqueue:
// cover property (p_tx_enqueue) else $info("UART TX enqueue not covered");

always_ff @(posedge clk) begin: c_tx_enqueue
    cover (rst_n && enq_tx_valid && enq_tx_ready);
end: c_tx_enqueue
/*  ---C2 */


/* C3a---  */
// property p_tx_start;
//     @(posedge clk)
//     rst_n && (dut.s_tx_state == F_TX_START);
// endproperty: p_tx_start

// cp_tx_start:
// cover property (p_tx_start) else $info("UART TX START state not covered");

always_ff @(posedge clk) begin: c_tx_start
    cover (rst_n && (dut.s_tx_state == F_TX_START));
end: c_tx_start
/*  ---C3a */


/* C3b---  */
// property p_tx_data0;
//     @(posedge clk)
//     rst_n && (dut.s_tx_state == F_TX_D0);
// endproperty: p_tx_data0

// cp_tx_data0:
// cover property (p_tx_data0) else $info("UART TX D0 state not covered");

always_ff @(posedge clk) begin: c_tx_data0
    cover (rst_n && (dut.s_tx_state == F_TX_D0));
end: c_tx_data0
/*  ---C3b */


/* C3c---  */
// property p_tx_data7;
//     @(posedge clk)
//     rst_n && (dut.s_tx_state == F_TX_D7);
// endproperty: p_tx_data7

// cp_tx_data7:
// cover property (p_tx_data7) else $info("UART TX D7 state not covered");

always_ff @(posedge clk) begin: c_tx_data7
    cover (rst_n && (dut.s_tx_state == F_TX_D7));
end: c_tx_data7
/*  ---C3c */


/* C3d---  */
// property p_tx_stop;
//     @(posedge clk)
//     rst_n && (dut.s_tx_state == F_TX_STOP0);
// endproperty: p_tx_stop

// cp_tx_stop:
// cover property (p_tx_stop) else $info("UART TX STOP state not covered");

always_ff @(posedge clk) begin: c_tx_stop
    cover (rst_n && (dut.s_tx_state == F_TX_STOP0));
end: c_tx_stop
/*  ---C3d */


/* C4a---  */
// property p_rx_start_detect;
//     @(posedge clk)
//     rst_n && (dut.s_rx_state == F_RX_START_DETECT);
// endproperty: p_rx_start_detect

// cp_rx_start_detect:
// cover property (p_rx_start_detect) else $info("UART RX start detection not covered");

always_ff @(posedge clk) begin: c_rx_start_detect
    cover (rst_n && (dut.s_rx_state == F_RX_START_DETECT));
end: c_rx_start_detect
/*  ---C4a */


/* C4b---  */
// property p_rx_data0;
//     @(posedge clk)
//     rst_n && (dut.s_rx_state == F_RX_D0);
// endproperty: p_rx_data0

// cp_rx_data0:
// cover property (p_rx_data0) else $info("UART RX D0 state not covered");

always_ff @(posedge clk) begin: c_rx_data0
    cover (rst_n && (dut.s_rx_state == F_RX_D0));
end: c_rx_data0
/*  ---C4b */


/* C5---  */
// property p_rx_byte_valid;
//     @(posedge clk)
//     rst_n && dut.w_p_rx_data_valid;
// endproperty: p_rx_byte_valid

// cp_rx_byte_valid:
// cover property (p_rx_byte_valid) else $info("UART received byte not covered");

always_ff @(posedge clk) begin: c_rx_byte_valid
    cover (rst_n && dut.w_p_rx_data_valid);
end: c_rx_byte_valid
/*  ---C5 */


/* C6---  */
// property p_rx_dequeue;
//     @(posedge clk)
//     rst_n && deq_rx_valid && deq_rx_ready;
// endproperty: p_rx_dequeue

// cp_rx_dequeue:
// cover property (p_rx_dequeue) else $info("UART RX dequeue not covered");

always_ff @(posedge clk) begin: c_rx_dequeue
    cover (rst_n && deq_rx_valid && deq_rx_ready);
end: c_rx_dequeue
/*  ---C6 */


/* C7---  */
// property p_baud_div_change;
//     @(posedge clk)
//     f_past_valid && rst_n && $past(rst_n) && (baud_div != $past(baud_div));
// endproperty: p_baud_div_change

// cp_baud_div_change:
// cover property (p_baud_div_change) else $info("UART baud-divisor change not covered");

always_ff @(posedge clk) begin: c_baud_div_change
    cover (f_past_valid && rst_n && $past(rst_n) && (baud_div != $past(baud_div)));
end: c_baud_div_change
/*  ---C7 */
