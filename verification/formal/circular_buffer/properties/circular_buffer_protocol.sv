/* P6---  */
// property p_enqueue_increments_level;
//     @(posedge clk) disable iff (!rst_n || !clr_n)
//     (will_enq && !will_deq) |=> level == ($past(level) + 1'b1);
// endproperty: p_enqueue_increments_level

// assert property (p_enqueue_increments_level) else $error("Circular buffer enqueue did not increment level");

always_ff @(posedge clk) begin: p_enqueue_increments_level
    if (f_past_valid && rst_n && clr_n && $past(rst_n) && $past(clr_n) &&
        $past(will_enq) && !$past(will_deq)) begin
        assert (level == ($past(level) + 1'b1));
    end
end: p_enqueue_increments_level
/*  ---P6 */


/* P7---  */
// property p_dequeue_decrements_level;
//     @(posedge clk) disable iff (!rst_n || !clr_n)
//     (!will_enq && will_deq) |=> level == ($past(level) - 1'b1);
// endproperty: p_dequeue_decrements_level

// assert property (p_dequeue_decrements_level) else $error("Circular buffer dequeue did not decrement level");

always_ff @(posedge clk) begin: p_dequeue_decrements_level
    if (f_past_valid && rst_n && clr_n && $past(rst_n) && $past(clr_n) &&
        !$past(will_enq) && $past(will_deq)) begin
        assert (level == ($past(level) - 1'b1));
    end
end: p_dequeue_decrements_level
/*  ---P7 */


/* P8---  */
// property p_simultaneous_holds_level;
//     @(posedge clk) disable iff (!rst_n || !clr_n)
//     (will_enq == will_deq) |=> level == $past(level);
// endproperty: p_simultaneous_holds_level

// assert property (p_simultaneous_holds_level) else $error("Circular buffer simultaneous operation changed level");

always_ff @(posedge clk) begin: p_simultaneous_holds_level
    if (f_past_valid && rst_n && clr_n && $past(rst_n) && $past(clr_n) &&
        ($past(will_enq) == $past(will_deq))) begin
        assert (level == $past(level));
    end
end: p_simultaneous_holds_level
/*  ---P8 */


/* P9---  */
// property p_no_underflow_overflow;
//     @(posedge clk) disable iff (!rst_n)
//     (empty |-> !will_deq) && (full |-> !will_enq);
// endproperty: p_no_underflow_overflow

// assert property (p_no_underflow_overflow) else $error("Circular buffer accepted an illegal operation");

always_ff @(posedge clk) begin: p_no_underflow_overflow
    if (rst_n) begin
        if (empty) assert (!will_deq);
        if (full)  assert (!will_enq);
    end
end: p_no_underflow_overflow
/*  ---P9 */
