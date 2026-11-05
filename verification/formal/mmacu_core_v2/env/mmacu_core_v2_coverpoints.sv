always_ff @(posedge clk) begin: c_mmacu
    cover(rst_n && a_valid && a_ready && start && last);
    cover(rst_n && dut.r_flushing);
    cover(rst_n && d_valid && !d_ready);
    cover(rst_n && d_valid && d_ready);
end: c_mmacu

