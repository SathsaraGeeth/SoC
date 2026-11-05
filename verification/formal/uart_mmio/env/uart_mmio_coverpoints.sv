always_ff @(posedge clk) begin: c_uart_mmio_activity
    cover (rst_n && req_valid && req_ready && req_we && req_addr[5:0] == 6'h10);
    cover (rst_n && req_valid && req_ready && !req_we && req_addr[5:0] == 6'h30);
    cover (rst_n && resp_valid && !resp_ready);
    cover (rst_n && dut.r_txctrl[0]);
end: c_uart_mmio_activity

