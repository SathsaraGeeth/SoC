always_ff @(posedge i_clk) begin: a_router_environment
    if (!f_past_valid)
        assume (!i_rst_n);
    if (f_past_valid && $past(i_rst_n))
        assume (i_rst_n);

    if (i_req_instr_valid)
        assume (dut.instr_valid_dir);
    if (i_req_data_valid && !dut.data_is_mmio)
        assume (dut.data_valid_dir);

    if (f_past_valid && i_rst_n && $past(i_rst_n)) begin
        if ($past(i_req_instr_valid && !o_req_instr_ready))
            assume ({i_req_instr_valid, i_req_instr_addr,
                     i_req_instr_thrd_id, i_req_instr_priv} ==
                    $past({i_req_instr_valid, i_req_instr_addr,
                           i_req_instr_thrd_id, i_req_instr_priv}));
        if ($past(i_req_data_valid && !o_req_data_ready))
            assume ({i_req_data_valid, i_req_data_addr, i_req_data_thrd_id,
                     i_req_data_priv, i_req_data_rw, i_req_data_lq,
                     i_req_data_sc, i_req_data_wstrb, i_req_data_wdata} ==
                    $past({i_req_data_valid, i_req_data_addr, i_req_data_thrd_id,
                           i_req_data_priv, i_req_data_rw, i_req_data_lq,
                           i_req_data_sc, i_req_data_wstrb, i_req_data_wdata}));
    end
end: a_router_environment
