always_ff @(posedge clk) begin: c_alu_activity
    cover (rst_n && req_valid && req_ready);
    cover (rst_n && res_valid && !res_ready);
    cover (rst_n && res_valid && dut.s2_alu_op == isa_pkg::ALU_MUL);
    cover (rst_n && res_valid && dut.s2_is_branch && br_taken);
    cover (rst_n && res_valid && dut.s2_is_jump);
end: c_alu_activity

