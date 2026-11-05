always_ff @(posedge clk) begin: p_memory_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (!dut.s0_valid[0]);
        assert (!dut.s1_enq_valid[0]);
        assert (!dut.s1_enq_valid[1]);
        assert (!page_req_valid);
        assert (!page_completion_pending);
        assert (!dut.r_page_read_pending);
        assert (dut.r_active_vtid[0] == '0);
    end
end: p_memory_reset

