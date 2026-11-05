always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    if (rst_n) begin
        assume (l0_a_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l0_b_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l0_c_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l1_a_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l1_b_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l1_c_fmt inside {OP_FMT_FP32, OP_FMT_FP16, OP_FMT_BF16});
        assume (l0_result_fmt inside {FMT_FP32, FMT_FP16, FMT_BF16});
        assume (l1_result_fmt inside {FMT_FP32, FMT_FP16, FMT_BF16});
    end
end
