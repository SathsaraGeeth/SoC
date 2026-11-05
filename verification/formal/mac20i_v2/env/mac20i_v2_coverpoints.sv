always_ff @(posedge clk) begin: c_mac20i_activity
    cover (rst_n && en && start);
    cover (rst_n && en && last);
    cover (rst_n && !en);
    cover (rst_n && done);
end: c_mac20i_activity
