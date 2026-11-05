always_ff @(posedge clk) begin: c_fp_iter_activity
    cover (rst_n && p0_out_valid && p0_out_thrd[XLEN-1:4] != '1);
    cover (rst_n && p1_out_valid && p1_out_thrd[XLEN-1:4] != '1);
    cover (rst_n && l1_in_valid && l1_in_ready && l1_op == DIV);
    cover (rst_n && l1_in_valid && l1_in_ready && l1_op == SQRT);
    cover (rst_n && dut.r_state == ITER_DONE && l1_out_valid);
end: c_fp_iter_activity
