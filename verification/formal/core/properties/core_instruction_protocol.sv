/* P2--- instruction requests are aligned and identify a legal thread. */
always_comb begin: p_instruction_metadata
    if (o_req_instr_valid) begin
        assert (o_req_instr_addr[2:0] == '0);
        assert (o_req_instr_thrd_id < core_pkg::NUM_HW_THRDS);
    end
    assert (o_page_msg_instr_ready);
end: p_instruction_metadata
/*  ---P2 */

/* P3--- accepted fetches become pending for their selected thread. */
always_ff @(posedge i_clk) begin: p_instruction_accept
    if (f_past_valid && i_rst_n && $past(i_rst_n) &&
        $past(o_req_instr_valid && i_req_instr_ready) &&
        !$past(i_resp_instr_valid && o_resp_instr_ready &&
               i_resp_instr_thrd_id == o_req_instr_thrd_id)) begin
        assert (dut.s1_p0_fetch_pending[$past(o_req_instr_thrd_id)]);
    end
end: p_instruction_accept
/*  ---P3 */

/* P4--- the fetch request remains stable while backpressured. */
always_ff @(posedge i_clk) begin: p_instruction_stability
    if (f_past_valid && i_rst_n && $past(i_rst_n) &&
        $past(o_req_instr_valid && !i_req_instr_ready)) begin
        assert (o_req_instr_valid);
        assert ({o_req_instr_addr, o_req_instr_thrd_id, o_req_instr_priv} ==
                $past({o_req_instr_addr, o_req_instr_thrd_id, o_req_instr_priv}));
    end
end: p_instruction_stability
/*  ---P4 */
