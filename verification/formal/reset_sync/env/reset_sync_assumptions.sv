always_ff @(posedge clk) begin: a_initial_reset
    if (!f_past_valid)
        assume (!async_rst_n);
end: a_initial_reset
