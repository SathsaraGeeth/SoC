/* P2: Request readiness is exactly the single-entry response capacity. */
always_comb
    assert (req_ready == (!resp_valid || resp_ready));

/* P3: Accepted requests produce the selected response and metadata. */
always_ff @(posedge clk) begin
    if (f_past_valid && rst_n && $past(rst_n && req_valid && req_ready)) begin
        assert (resp_valid == $past(resp_expected));
        assert (resp_port == $past(req_port));
        assert (resp_thrd == $past(req_thrd));
    end
end

/* P4: A blocked response is stable. */
always_ff @(posedge clk) begin
    if (f_past_valid && rst_n && $past(rst_n && resp_valid && !resp_ready)) begin
        assert (resp_valid);
        assert (rdata == $past(rdata));
        assert (resp_port == $past(resp_port));
        assert (resp_thrd == $past(resp_thrd));
    end
end
