/* P2: MTIME advances exactly once on every active clock. */
always_ff @(posedge clk) begin: p_mtime_increments
    if (f_past_valid && rst_n && $past(rst_n))
        assert (dut.mtime_q == $past(dut.mtime_q) + 64'd1);
end: p_mtime_increments

/* P3: The interrupt is the exact comparator relation. */
always_ff @(posedge clk) begin: p_irq_threshold
    if (rst_n)
        assert (irq_timer == (dut.mtime_q >= dut.mtimecmp_q));
end: p_irq_threshold

