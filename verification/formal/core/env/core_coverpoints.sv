always_ff @(posedge i_clk) begin: c_core_boundary
    cover (i_rst_n && o_req_instr_valid && i_req_instr_ready);
    cover (i_rst_n && i_resp_instr_valid && o_resp_instr_ready);
    cover (i_rst_n && o_req_data_valid && i_req_data_ready);
    cover (i_rst_n && o_page_msg_valid && !i_page_msg_ready);
end: c_core_boundary
