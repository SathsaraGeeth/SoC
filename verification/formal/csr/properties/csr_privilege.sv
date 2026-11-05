/* P4: Traps select their requested privilege level. */
always_ff @(posedge clk) begin: p_csr_trap
    if (f_past_valid && rst_n && $past(rst_n && trap_we)) begin
        if ($past(trap_to_s))
            assert (priv_mode_vec[$past(wthrd_id)] == isa_pkg::PRIV_MODE_S);
        else
            assert (priv_mode_vec[$past(wthrd_id)] == isa_pkg::PRIV_MODE_M);
    end
end: p_csr_trap

/* P5: Return instructions restore the saved privilege fields. */
always_ff @(posedge clk) begin: p_csr_return
    if (f_past_valid && rst_n && $past(rst_n && !trap_we && mret_we))
        assert (priv_mode_vec[$past(wthrd_id)] ==
                $past(dut.r_mpp[wthrd_id]));
    if (f_past_valid && rst_n
        && $past(rst_n && !trap_we && !mret_we && sret_we)) begin
        assert (priv_mode_vec[$past(wthrd_id)] ==
                ($past(dut.r_spp[wthrd_id])
                 ? isa_pkg::PRIV_MODE_S : isa_pkg::PRIV_MODE_U));
    end
end: p_csr_return
