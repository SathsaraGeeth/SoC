/* P4: Every stage-two operation selects the correct result. */
always_ff @(posedge clk) begin: p_alu_result
    logic [XLEN-1:0] expected;

    expected = '0;
    unique case (dut.s2_alu_op)
        isa_pkg::ALU_ADD:  expected = dut.s2_op_a + dut.s2_op_b;
        isa_pkg::ALU_SUB:  expected = dut.s2_op_a - dut.s2_op_b;
        isa_pkg::ALU_SLL:  expected = dut.s2_op_a << dut.s2_op_b[$clog2(XLEN)-1:0];
        isa_pkg::ALU_SLT:  expected = XLEN'($signed(dut.s2_op_a) < $signed(dut.s2_op_b));
        isa_pkg::ALU_SLTU: expected = XLEN'(dut.s2_op_a < dut.s2_op_b);
        isa_pkg::ALU_XOR:  expected = dut.s2_op_a ^ dut.s2_op_b;
        isa_pkg::ALU_SRL:  expected = dut.s2_op_a >> dut.s2_op_b[$clog2(XLEN)-1:0];
        isa_pkg::ALU_SRA:  expected = $signed(dut.s2_op_a) >>> dut.s2_op_b[$clog2(XLEN)-1:0];
        isa_pkg::ALU_OR:   expected = dut.s2_op_a | dut.s2_op_b;
        isa_pkg::ALU_AND:  expected = dut.s2_op_a & dut.s2_op_b;
        isa_pkg::ALU_MUL:  expected = dut.s2_mul_result[XLEN-1:0];
        default:           expected = dut.s2_result_comb;
    endcase
    if (dut.s2_alu_word)
        expected = {{(XLEN-32){expected[31]}}, expected[31:0]};

    if (rst_n && res_valid && !dut.s2_is_branch
        && !dut.s2_is_jump && !dut.s2_is_jalr)
        assert (result == expected);
end: p_alu_result

/* P5: Jump and branch metadata obey their architectural definitions. */
always_ff @(posedge clk) begin: p_alu_control_flow
    if (rst_n && res_valid) begin
        if (dut.s2_is_jump || dut.s2_is_jalr)
            assert (result == dut.s2_op_a + XLEN'(isa_pkg::INST_W / 8));
        if (dut.s2_is_jump)
            assert (br_taken);
        if (!dut.s2_is_jump && !dut.s2_is_branch)
            assert (!br_taken);
    end
end: p_alu_control_flow

