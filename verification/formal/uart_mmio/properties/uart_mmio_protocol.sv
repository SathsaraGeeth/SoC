always_comb begin: p_uart_mmio_ready
    assert (req_ready == (!dut.r_resp_busy && !dut.r_req_valid));
    if (rst_n) begin
        assert (resp_valid == dut.r_resp_busy);
        assert (!(dut.r_req_valid && dut.r_resp_busy));
    end
end: p_uart_mmio_ready

always_ff @(posedge clk) begin: p_uart_mmio_response
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if ($past(resp_valid && !resp_ready)) begin
            assert (resp_valid);
            assert (resp_rdata == $past(resp_rdata));
            assert (resp_thrd == $past(resp_thrd));
        end
        if ($past(req_valid && req_ready)) begin
            assert (dut.r_req_valid);
            assert (dut.r_req_thrd == $past(req_thrd));
            assert (dut.r_req_we == $past(req_we));
            assert (dut.r_req_wdata == $past(req_wdata));
            assert (dut.r_req_wstrb == $past(req_wstrb));
            assert (dut.r_req_priv == $past(req_priv));
        end
        if ($past(dut.r_req_valid && dut.w_req_complete)) begin
            assert (resp_valid);
            assert (resp_thrd == $past(dut.r_req_thrd));
            assert (!resp_sc_succ);
        end
    end
end: p_uart_mmio_response
