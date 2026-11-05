always_ff @(posedge clk) begin: c_fpu_datapath_activity
    cover (rst_n && l0_in_valid && l0_in_ready);
    cover (rst_n && l1_in_valid && l1_in_ready);
    cover (rst_n && l0_out_valid);
    cover (rst_n && l1_out_valid);
    cover (rst_n && l1_in_valid && l1_op == DIV);
    cover (rst_n && l1_in_valid && l1_op == SQRT);
end: c_fpu_datapath_activity
