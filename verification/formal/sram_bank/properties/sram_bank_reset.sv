/* P1: Synchronous reset clears visible response and reservation state. */
always_ff @(posedge clk) begin
    if (f_past_valid && $past(!rst_n)) begin
        assert (!resp_valid);
        assert (!dut.r_resv_valid);
        assert (rdata == '0);
        assert (resp_port == '0);
        assert (resp_thrd == '0);
    end
end

