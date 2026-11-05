/* P5--- data requests identify a legal thread and preserve byte-lane shape. */
always_comb begin: p_data_metadata
    if (o_req_data_valid) begin
        assert (o_req_data_thrd_id < core_pkg::NUM_HW_THRDS);
        if (!o_req_data_rw)
            assert (o_req_data_wstrb == '0);
    end
end: p_data_metadata
/*  ---P5 */

/* P6--- accepted LSU requests become pending until response/fault completion. */
always_ff @(posedge i_clk) begin: p_data_accept
    if (f_past_valid && i_rst_n && $past(i_rst_n) &&
        $past(o_req_data_valid && i_req_data_ready) &&
        !$past(i_resp_data_valid && o_resp_data_ready &&
               i_resp_data_thrd_id == o_req_data_thrd_id)) begin
        assert (dut.r_lsu_request_pending_vec[$past(o_req_data_thrd_id)]);
    end
end: p_data_accept
/*  ---P6 */

/* P7--- LSU request payload remains stable while backpressured. */
always_ff @(posedge i_clk) begin: p_data_stability
    if (f_past_valid && i_rst_n && $past(i_rst_n) &&
        $past(o_req_data_valid && !i_req_data_ready)) begin
        assert (o_req_data_valid);
        assert ({o_req_data_addr, o_req_data_thrd_id, o_req_data_priv,
                 o_req_data_rw, o_req_data_lq, o_req_data_sc,
                 o_req_data_wstrb, o_req_data_wdata} ==
                $past({o_req_data_addr, o_req_data_thrd_id, o_req_data_priv,
                       o_req_data_rw, o_req_data_lq, o_req_data_sc,
                       o_req_data_wstrb, o_req_data_wdata}));
    end
end: p_data_stability
/*  ---P7 */
