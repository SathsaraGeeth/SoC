always_ff @(posedge clk) begin: p_sys_address_first
    if (rst_n && f_past_valid
     && $past(rst_n && start && dut.r_state == 1'b0)) begin
        assert (addr_valid);
        assert (addr_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1] == 1'b0);
        assert (addr_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W] == $past(dense));
        assert (addr_data[ADDR_FLAGS_W+MAC_W+XLEN +: VIR_ADDR_W] == $past(base_addr));
        assert (addr_data[ADDR_FLAGS_W+MAC_W +: XLEN] == $past(tid));
        assert (addr_data[ADDR_FLAGS_W +: MAC_W] == $past(mac_type));
        assert (addr_data[ADDR_FLAGS_W-1:0] ==
                {1'b0, $past(dense ? a_tiles == 1 : cmd_last),
                         $past(dense ? 1'b1 : cmd_start)});
    end
end: p_sys_address_first
