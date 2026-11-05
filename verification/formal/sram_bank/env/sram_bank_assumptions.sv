always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    assume (!(lr && sc));
    if (lr)
        assume (!we);
    if (sc)
        assume (we);
end

