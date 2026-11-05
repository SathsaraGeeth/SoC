/* P1--- reset initializes the per-thread fetch and LSU state. */
always_ff @(posedge i_clk) begin: p_core_reset
    if (f_past_valid && !$past(i_rst_n)) begin
        for (int thread_id = 0; thread_id < core_pkg::NUM_HW_THRDS; thread_id++) begin
            assert (dut.s1_p0_npc[thread_id] == '0);
            assert (dut.s1_p0_fetch_pc[thread_id] == '0);
            assert (dut.s1_p0_npc_valid[thread_id]);
            assert (!dut.s1_p0_fetch_pending[thread_id]);
            assert (!dut.s1_p0_instr_valid[thread_id]);
            assert (!dut.r_p0_drop_resp[thread_id]);
            assert (!dut.r_lsu_request_pending_vec[thread_id]);
            assert (!dut.r_lsu_resp_valid_vec[thread_id]);
            assert (!dut.r_lsu_pf_valid_vec[thread_id]);
            if (thread_id == 0)
                assert (!dut.s1_p0_sleep[thread_id]);
            else
                assert (dut.s1_p0_sleep[thread_id]);
        end
    end
end: p_core_reset
/*  ---P1 */
