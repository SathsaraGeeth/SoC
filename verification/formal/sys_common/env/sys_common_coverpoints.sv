always_ff @(posedge clk) begin
    cover (f_past_valid && rst_n && en && clr_n);
    cover (f_past_valid && rst_n && !clr_n);
    cover (f_past_valid && rst_n && start);
    cover (f_past_valid && rst_n && done);
    cover (f_past_valid && rst_n && ptr == 4);
end

