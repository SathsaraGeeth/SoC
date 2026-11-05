always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    if (rst_n && l1_in_valid && (l1_op inside {DIV, SQRT})) begin
        assume (l1_a_fmt == OP_FMT_FP32);
        assume (l1_b_fmt == OP_FMT_FP32);
        assume (l1_result_fmt == FMT_FP32);
    end
end
