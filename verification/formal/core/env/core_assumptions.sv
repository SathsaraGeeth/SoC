always_ff @(posedge i_clk) begin: a_core_environment
    if (!f_past_valid)
        assume (!i_rst_n);
    if (f_past_valid && $past(i_rst_n))
        assume (i_rst_n);

    if (i_resp_instr_valid)
        assume (dut.s1_p0_fetch_pending[i_resp_instr_thrd_id] ||
                dut.r_p0_drop_resp[i_resp_instr_thrd_id]);
    if (i_resp_data_valid)
        assume (dut.r_lsu_request_pending_vec[i_resp_data_thrd_id]);
    if (i_page_msg_instr_valid &&
        dut.s0_p0_page_msg_instr.msg_type == memory_pkg::PAGE_MSG_FAULT)
        assume (dut.s1_p0_fetch_pending[dut.s0_p0_pf_msg_instr.thrd_id] ||
                dut.r_p0_drop_resp[dut.s0_p0_pf_msg_instr.thrd_id]);
    if (i_page_msg_data_valid &&
        dut.s1_p0_page_msg_data.msg_type == memory_pkg::PAGE_MSG_FAULT)
        assume (dut.r_lsu_request_pending_vec[
            dut.s1_p0_pf_msg_data.thrd_id[$clog2(core_pkg::NUM_HW_THRDS)-1:0]]);

    if (f_past_valid && i_rst_n && $past(i_rst_n)) begin
        if ($past(i_resp_instr_valid && !o_resp_instr_ready))
            assume ({i_resp_instr_valid, i_resp_instr,
                     i_resp_instr_thrd_id} ==
                    $past({i_resp_instr_valid, i_resp_instr,
                           i_resp_instr_thrd_id}));
        if ($past(i_resp_data_valid && !o_resp_data_ready))
            assume ({i_resp_data_valid, i_resp_data_rdata,
                     i_resp_data_sc_ok, i_resp_data_thrd_id} ==
                    $past({i_resp_data_valid, i_resp_data_rdata,
                           i_resp_data_sc_ok, i_resp_data_thrd_id}));
    end
end: a_core_environment
