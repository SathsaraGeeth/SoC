always_ff @(posedge clk) begin
    if (!f_past_valid)
        assume (!rst_n);
    assume (!(issued_instr.instr.is_branch && issued_instr.instr.is_jump));
    if (issued_instr.instr.is_jalr)
        assume (issued_instr.instr.is_jump);
    if (issued_instr.instr.is_branch || issued_instr.instr.is_jump)
        assume (issued_instr.instr.alu_op == isa_pkg::ALU_ADD);
end
