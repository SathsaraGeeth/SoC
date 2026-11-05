always_ff @(posedge clk) begin: c_memory_activity
    cover (rst_n && req_valid && req_ready_a[0]);
    cover (rst_n && page_msg_valid && page_msg_in_ready_a[0]);
    cover (rst_n && page_req_valid && !page_req_ready);
    cover (rst_n && page_completion_pending);
    cover (rst_n && resp_valid_a[0] && resp_ready);
end: c_memory_activity

