always_ff @(posedge clk) begin
    if (!f_initial)
        assume (!rst_n);
    assume (ptr <= 4);
end
