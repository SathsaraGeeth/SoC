always_ff @(posedge clk) begin
    cover (f_past_valid && rst_n && req_valid && req_ready && we);
    cover (f_past_valid && rst_n && req_valid && req_ready && lr);
    cover (f_past_valid && rst_n && req_valid && req_ready && sc && sc_succ);
    cover (f_past_valid && rst_n && resp_valid && !resp_ready);
end

