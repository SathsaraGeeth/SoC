always_ff @(posedge clk) begin: c_fpu_activity
    cover (rst_n && req_valid && req_ready && dut.w_is_simple);
    cover (rst_n && res_valid && !res_ready);
    cover (rst_n && res_valid && res_ready);
end: c_fpu_activity
