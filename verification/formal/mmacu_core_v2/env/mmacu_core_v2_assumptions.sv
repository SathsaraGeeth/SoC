always_ff @(posedge clk) begin
    if (!f_past_valid) assume(!rst_n);
    if (f_past_valid && $past(rst_n)) assume(rst_n);
    assume(a_valid==b_valid);
    if (start || last || end_tile) assume(a_valid && b_valid);
end

