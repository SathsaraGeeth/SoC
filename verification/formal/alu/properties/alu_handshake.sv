/* P2: Output and metadata remain stable under backpressure. */
always_ff @(posedge clk) begin: p_alu_output_stable
    if (f_past_valid && rst_n && $past(rst_n)
        && $past(res_valid && !res_ready)) begin
        assert (res_valid);
        assert (result == $past(result));
        assert (res_thrd_id == $past(res_thrd_id));
        assert (br_target == $past(br_target));
        assert (br_taken == $past(br_taken));
    end
end: p_alu_output_stable

/* P3: Public output-valid and metadata exactly expose stage two. */
always_ff @(posedge clk) begin: p_alu_stage_two
    if (rst_n) begin
        assert (res_valid == dut.s2_valid);
        assert (res_thrd_id == dut.s2_thrd_id);
        assert (br_target == dut.s2_br_taken_target);
    end
end: p_alu_stage_two
/* P4: Pipeline control metadata preserves decoder invariants. */
always_ff @(posedge clk) begin: p_alu_control_metadata
    if (rst_n) begin
        assert (!(dut.s1_is_branch && dut.s1_is_jump));
        assert (!(dut.s2_is_branch && dut.s2_is_jump));
        if (dut.s1_is_jalr)
            assert (dut.s1_is_jump);
        if (dut.s2_is_jalr)
            assert (dut.s2_is_jump);
        if (dut.s1_is_branch || dut.s1_is_jump)
            assert (dut.s1_alu_op == isa_pkg::ALU_ADD);
        if (dut.s2_is_branch || dut.s2_is_jump)
            assert (dut.s2_alu_op == isa_pkg::ALU_ADD);
    end
end: p_alu_control_metadata

