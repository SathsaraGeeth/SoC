/* P1: Every thread boots in machine mode with interrupts disabled. */
always_ff @(posedge clk) begin: p_csr_reset
    if (f_past_valid && !$past(rst_n)) begin
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            assert (priv_mode_vec[t] == isa_pkg::PRIV_MODE_M);
            assert (!dut.r_mie[t]);
            assert (!dut.r_sie[t]);
        end
    end
end: p_csr_reset

