/* C1---  */
// property p_reset_release;
//     @(posedge clk)
//     rst_n && clr_n && empty && (level == '0);
// endproperty: p_reset_release

// cp_reset_release:
// cover property (p_reset_release) else $info("Circular buffer reset release not covered");

always_ff @(posedge clk) begin: c_reset_release
    cover (rst_n && clr_n && empty && (level == '0));
end: c_reset_release
/*  ---C1 */


/* C2---  */
// property p_enqueue;
//     @(posedge clk)
//     rst_n && clr_n && will_enq;
// endproperty: p_enqueue

// cp_enqueue:
// cover property (p_enqueue) else $info("Circular buffer enqueue not covered");

always_ff @(posedge clk) begin: c_enqueue
    cover (rst_n && clr_n && will_enq);
end: c_enqueue
/*  ---C2 */


/* C3---  */
// property p_full;
//     @(posedge clk)
//     rst_n && clr_n && full;
// endproperty: p_full

// cp_full:
// cover property (p_full) else $info("Circular buffer full state not covered");

always_ff @(posedge clk) begin: c_full
    cover (rst_n && clr_n && full);
end: c_full
/*  ---C3 */


/* C4---  */
// property p_simultaneous_enqueue_dequeue;
//     @(posedge clk)
//     rst_n && clr_n && will_enq && will_deq;
// endproperty: p_simultaneous_enqueue_dequeue

// cp_simultaneous_enqueue_dequeue:
// cover property (p_simultaneous_enqueue_dequeue) else $info("Circular buffer simultaneous operation not covered");

always_ff @(posedge clk) begin: c_simultaneous_enqueue_dequeue
    cover (rst_n && clr_n && will_enq && will_deq);
end: c_simultaneous_enqueue_dequeue
/*  ---C4 */


/* C5---  */
// property p_pointer_wrap;
//     @(posedge clk)
//     f_past_valid && rst_n && clr_n && $past(rst_n) && $past(clr_n) &&
//     ($past(dut.r_tail_ptr) == (DEPTH - 1)) && will_enq && (dut.r_tail_ptr == '0);
// endproperty: p_pointer_wrap

// cp_pointer_wrap:
// cover property (p_pointer_wrap) else $info("Circular buffer pointer wrap not covered");

always_ff @(posedge clk) begin: c_pointer_wrap
    cover (f_past_valid && rst_n && clr_n && $past(rst_n) && $past(clr_n) &&
           ($past(dut.r_tail_ptr) == $clog2(DEPTH)'(DEPTH - 1)) &&
           $past(will_enq) && (dut.r_tail_ptr == '0));
end: c_pointer_wrap
/*  ---C5 */


/* C6---  */
// property p_clear_nonempty;
//     @(posedge clk)
//     f_past_valid && !$past(clr_n) && ($past(level) != '0) && empty;
// endproperty: p_clear_nonempty

// cp_clear_nonempty:
// cover property (p_clear_nonempty) else $info("Circular buffer synchronous clear not covered");

always_ff @(posedge clk) begin: c_clear_nonempty
    cover (f_past_valid && rst_n && !$past(clr_n) && ($past(level) != '0) && empty);
end: c_clear_nonempty
/*  ---C6 */
