always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    if (rst_n && req_valid)
        assume (dut.w_is_simple);
end
