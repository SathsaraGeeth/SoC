/* P2---  */
// property p_empty_flag;
//     @(posedge clk) disable iff (!rst_n)
//     empty == (level == '0);
// endproperty: p_empty_flag

// assert property (p_empty_flag) else $error("Circular buffer empty flag/level mismatch");

always_ff @(posedge clk) begin: p_empty_flag
    if (rst_n) begin
        assert (empty == (level == '0));
    end
end: p_empty_flag
/*  ---P2 */


/* P3---  */
// property p_full_flag;
//     @(posedge clk) disable iff (!rst_n)
//     full == (level == DEPTH);
// endproperty: p_full_flag

// assert property (p_full_flag) else $error("Circular buffer full flag/level mismatch");

always_ff @(posedge clk) begin: p_full_flag
    if (rst_n) begin
        assert (full == (level == $bits(level)'(DEPTH)));
    end
end: p_full_flag
/*  ---P3 */


/* P4---  */
// property p_level_in_bounds;
//     @(posedge clk) disable iff (!rst_n)
//     level <= DEPTH;
// endproperty: p_level_in_bounds

// assert property (p_level_in_bounds) else $error("Circular buffer level exceeded depth");

always_ff @(posedge clk) begin: p_level_in_bounds
    if (rst_n) begin
        assert (level <= $bits(level)'(DEPTH));
    end
end: p_level_in_bounds
/*  ---P4 */


/* P5---  */
// property p_ready_status;
//     @(posedge clk) disable iff (!rst_n)
//     (enq_ready == !full) && (deq_ready == !empty);
// endproperty: p_ready_status

// assert property (p_ready_status) else $error("Circular buffer ready/status mismatch");

always_ff @(posedge clk) begin: p_ready_status
    if (rst_n) begin
        assert (enq_ready == !full);
        assert (deq_ready == !empty);
    end
end: p_ready_status
/*  ---P5 */
