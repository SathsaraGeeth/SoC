/* P10---  */
// property p_fifo_order;
//     @(posedge clk) disable iff (!rst_n || !clr_n)
//     (f_sample_pending && (f_older_count == '0) && will_deq) |->
//     (head_data == f_sample_data);
// endproperty: p_fifo_order

// assert property (p_fifo_order) else $error("Circular buffer violated FIFO ordering");

always_ff @(posedge clk) begin: p_fifo_order
    if (rst_n && clr_n && f_sample_pending &&
        (f_older_count == '0) && will_deq) begin
        assert (head_data == f_sample_data);
    end
end: p_fifo_order
/*  ---P10 */
