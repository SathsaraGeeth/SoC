always_ff @(posedge i_clk) begin: c_router_paths
    cover (i_rst_n && i_req_instr_valid && o_req_instr_ready && dut.instr_dir == 0);
    cover (i_rst_n && i_req_instr_valid && o_req_instr_ready && dut.instr_dir == 3);
    cover (i_rst_n && i_req_data_valid && o_req_data_ready && dut.data_is_mmio);
    cover (i_rst_n && o_resp_instr_valid && !i_resp_instr_ready);
    cover (i_rst_n && o_resp_data_valid && !i_resp_data_ready);
    cover (i_rst_n && o_core_page_msg_instr_valid && !i_core_page_msg_instr_ready);
end: c_router_paths
