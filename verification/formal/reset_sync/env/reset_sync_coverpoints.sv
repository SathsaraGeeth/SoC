always_ff @(posedge clk) begin: c_reset_release
    cover (f_past_valid && async_rst_n && rst_n);
end: c_reset_release

always_ff @(posedge clk) begin: c_reassert_after_release
    cover (f_past_valid && !async_rst_n && $past(rst_n));
end: c_reassert_after_release
