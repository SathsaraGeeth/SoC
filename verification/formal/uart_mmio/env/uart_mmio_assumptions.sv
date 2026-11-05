always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
end

