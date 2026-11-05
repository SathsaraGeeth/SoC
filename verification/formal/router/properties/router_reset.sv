/* P1--- reset clears every externally visible response buffer. */
always_ff @(posedge i_clk) begin: p_router_reset
    if (f_past_valid && !$past(i_rst_n)) begin
        assert (!o_resp_instr_valid);
        assert (!o_resp_data_valid);
        assert (!o_core_page_msg_instr_valid);
        assert (!o_core_page_msg_data_valid);
        for (int direction = 0; direction < 4; direction++) begin
            assert (!dut.r_mem_resp_instr_valid[direction]);
            assert (!dut.r_mem_resp_data_valid[direction]);
        end
    end
end: p_router_reset
/*  ---P1 */
