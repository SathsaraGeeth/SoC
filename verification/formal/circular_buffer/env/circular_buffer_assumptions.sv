// property p_reset_before_past_valid;
//     @(posedge clk)
//     !f_past_valid |-> !rst_n;
// endproperty: p_reset_before_past_valid

// a_reset_before_past_valid:
//     assume property (p_reset_before_past_valid);


always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
end
