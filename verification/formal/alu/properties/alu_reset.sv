/* P1: Reset empties both pipeline stages. */
always_ff @(posedge clk) begin: p_alu_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (!dut.s1_valid);
        assert (!dut.s2_valid);
        assert (!res_valid);
    end
end: p_alu_reset

