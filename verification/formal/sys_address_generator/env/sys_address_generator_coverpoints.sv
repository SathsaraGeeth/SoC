always_ff @(posedge clk) begin: c_sys_address_activity
    cover (rst_n && start);
    cover (rst_n && addr_valid && !addr_ready);
    cover (rst_n && addr_valid && addr_ready);
    cover (rst_n && done);
end: c_sys_address_activity
