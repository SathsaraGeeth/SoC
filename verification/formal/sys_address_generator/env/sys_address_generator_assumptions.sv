always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    if (rst_n && start) begin
        assume (a_tiles > 0);
        assume (b_tiles > 0);
        assume (a_tiles <= 2);
        assume (b_tiles <= 2);
    end
end
