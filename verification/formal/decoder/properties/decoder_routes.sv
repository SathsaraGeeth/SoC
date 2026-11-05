/* P4: Major integer opcodes route to the expected units. */
always_ff @(posedge clk) begin: p_major_routes
    unique case (instr[6:0])
        7'b0000011,
        7'b0100011: assert (decoded.fu == FU_LSU);
        7'b1100011: begin
            assert (decoded.fu == FU_ALU);
            assert (decoded.is_branch);
            assert (decoded.rawhz_t == RAWHZ_RS1_RS2);
        end
        7'b1101111: begin
            assert (decoded.fu == FU_ALU);
            assert (decoded.is_jump);
            assert (!decoded.is_jalr);
        end
        7'b1100111: begin
            assert (decoded.fu == FU_ALU);
            assert (decoded.is_jump);
            assert (decoded.is_jalr);
        end
        7'b0110111: begin
            assert (decoded.fu == FU_ALU);
            assert (decoded.use_imm);
            assert (!decoded.use_pc);
            assert (decoded.rs1 == '0);
        end
        7'b0010111: begin
            assert (decoded.fu == FU_ALU);
            assert (decoded.use_imm);
            assert (decoded.use_pc);
        end
        default: begin
        end
    endcase
end: p_major_routes

