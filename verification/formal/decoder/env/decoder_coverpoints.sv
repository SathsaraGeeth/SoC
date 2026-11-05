always_ff @(posedge clk) begin: c_decoder_classes
    cover (instr[6:0] == 7'b0110011 && decoded.fu == FU_ALU);
    cover (instr[6:0] == 7'b0000011 && decoded.fu == FU_LSU);
    cover (instr[6:0] == 7'b1100011 && decoded.is_branch);
    cover (instr[6:0] == 7'b1101111 && decoded.is_jump);
    cover (instr[6:0] == 7'b1110011 && decoded.fu == FU_CSR);
    cover (decoded.fu == FU_FPU);
end: c_decoder_classes

