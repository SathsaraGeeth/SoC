/* P6--- all core response payloads remain stable under backpressure. */
always_ff @(posedge i_clk) begin: p_response_stability
    if (f_past_valid && i_rst_n && $past(i_rst_n)) begin
        if ($past(o_resp_instr_valid && !i_resp_instr_ready)) begin
            assert (o_resp_instr_valid);
            assert ({o_resp_instr, o_resp_instr_thrd_id} ==
                    $past({o_resp_instr, o_resp_instr_thrd_id}));
        end
        if ($past(o_resp_data_valid && !i_resp_data_ready)) begin
            assert (o_resp_data_valid);
            assert ({o_resp_data_rdata, o_resp_data_sc_ok,
                     o_resp_data_thrd_id} ==
                    $past({o_resp_data_rdata, o_resp_data_sc_ok,
                           o_resp_data_thrd_id}));
        end
        if ($past(o_core_page_msg_instr_valid &&
                  !i_core_page_msg_instr_ready)) begin
            assert (o_core_page_msg_instr_valid);
            assert (o_core_page_msg_instr == $past(o_core_page_msg_instr));
        end
        if ($past(o_core_page_msg_data_valid &&
                  !i_core_page_msg_data_ready)) begin
            assert (o_core_page_msg_data_valid);
            assert (o_core_page_msg_data == $past(o_core_page_msg_data));
        end
    end
end: p_response_stability
/*  ---P6 */
