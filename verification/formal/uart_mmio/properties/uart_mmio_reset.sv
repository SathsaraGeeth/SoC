always_ff @(posedge clk) begin: p_uart_mmio_reset
    if (f_past_valid && !$past(rst_n)) begin
        assert (dut.r_txctrl == '0);
        assert (dut.r_rxctrl == '0);
        assert (dut.r_ie == '0);
        assert (dut.r_div == 64'd1085);
        assert (!dut.r_req_valid);
        assert (!resp_valid);
        assert (!dut.r_resp_busy);
    end
end: p_uart_mmio_reset

