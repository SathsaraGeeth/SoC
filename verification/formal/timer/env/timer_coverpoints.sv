always_ff @(posedge clk) begin: c_timer_activity
    cover (rst_n && req_valid && req_ready && !req_we);
    cover (rst_n && req_valid && req_ready && req_we
           && req_addr[3:0] == 4'h8);
    cover (rst_n && resp_valid && !resp_ready);
    cover (rst_n && irq_timer);
end: c_timer_activity

