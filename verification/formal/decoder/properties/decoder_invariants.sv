/* P1: The raw instruction and common fields are preserved. */
always_ff @(posedge clk) begin: p_raw_fields
    assert (decoded.raw == instr);
    assert (decoded.rd == instr[11:7]);
    assert (decoded.funct3 == instr[14:12]);
end: p_raw_fields

/* P2: No write enable can target x0. */
always_ff @(posedge clk) begin: p_x0_write
    if (decoded.rd == '0)
        assert (!decoded.rf_wen);
end: p_x0_write

/* P3: Specialized flags imply their parent operation class. */
always_ff @(posedge clk) begin: p_flag_implications
    if (decoded.is_jalr)
        assert (decoded.is_jump);
    if (decoded.is_branch || decoded.is_jump)
        assert (decoded.fu == FU_ALU);
    if (decoded.csr_wen)
        assert (decoded.fu == FU_CSR);
    if (decoded.ls_wen || decoded.ls_lq || decoded.ls_sc)
        assert (decoded.fu == FU_LSU);
    if (decoded.use_pc)
        assert (decoded.use_imm);
end: p_flag_implications

