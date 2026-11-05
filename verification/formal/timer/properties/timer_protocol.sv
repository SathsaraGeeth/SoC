/* P4: A pending response is the only source of request backpressure. */
always_ff @(posedge clk) begin: p_request_ready
    if (rst_n)
        assert (req_ready == (!resp_valid || resp_ready));
end: p_request_ready

/* P5: Response payload and valid remain stable while stalled. */
always_ff @(posedge clk) begin: p_response_stable
    if (f_past_valid && rst_n && $past(rst_n)
        && $past(resp_valid && !resp_ready)) begin
        assert (resp_valid);
        assert (resp_rdata == $past(resp_rdata));
    end
end: p_response_stable

/* P6: Every accepted request produces a response. */
always_ff @(posedge clk) begin: p_request_response
    if (f_past_valid && rst_n && $past(rst_n)
        && $past(req_valid && req_ready))
        assert (resp_valid);
end: p_request_response

