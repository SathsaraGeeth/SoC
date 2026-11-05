function automatic logic [63:0] f_merge(
    input logic [63:0] old_value, input logic [63:0] new_value,
    input logic [7:0] mask
);
    logic [63:0] value;
    value = old_value;
    for (int i = 0; i < 8; i++)
        if (mask[i]) value[i*8 +: 8] = new_value[i*8 +: 8];
    return value;
endfunction

always_ff @(posedge clk) begin: p_uart_mmio_registers
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if ($past(dut.r_req_valid && dut.r_req_we &&
                  dut.r_req_priv != isa_pkg::PRIV_MODE_U)) begin
            unique case ($past(dut.r_req_type))
                3'd2: assert (dut.r_txctrl == f_merge($past(dut.r_txctrl),
                                                       $past(dut.r_req_wdata),
                                                       $past(dut.r_req_wstrb)));
                3'd3: assert (dut.r_rxctrl == f_merge($past(dut.r_rxctrl),
                                                       $past(dut.r_req_wdata),
                                                       $past(dut.r_req_wstrb)));
                3'd4: assert (dut.r_ie == (f_merge($past(dut.r_ie),
                                                   $past(dut.r_req_wdata),
                                                   $past(dut.r_req_wstrb)) & 64'h3));
                3'd6: assert (dut.r_div == f_merge($past(dut.r_div),
                                                   $past(dut.r_req_wdata),
                                                   $past(dut.r_req_wstrb)));
                default: begin end
            endcase
        end else begin
            assert (dut.r_txctrl == $past(dut.r_txctrl));
            assert (dut.r_rxctrl == $past(dut.r_rxctrl));
            assert (dut.r_ie == $past(dut.r_ie));
            assert (dut.r_div == $past(dut.r_div));
        end
    end
end: p_uart_mmio_registers

