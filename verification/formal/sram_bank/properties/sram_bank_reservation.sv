/* P5: Public SC success is the exact reservation match. */
always_comb begin
    assert (sc_succ == (sc && dut.r_resv_valid &&
                        dut.r_resv_addr == waddr &&
                        dut.r_resv_thrd == req_thrd &&
                        dut.r_resv_wstrb == wstrb));
end

/* P6: An accepted LR installs its reservation. */
always_ff @(posedge clk) begin
    if (f_past_valid && rst_n &&
        $past(rst_n && req_valid && req_ready && lr)) begin
        assert (dut.r_resv_valid);
        assert (dut.r_resv_addr == $past(raddr));
        assert (dut.r_resv_thrd == $past(req_thrd));
        assert (dut.r_resv_wstrb == $past(wstrb));
    end
end

