always_comb begin: p_memory_combinational
    assert (page_msg_in_ready_a[0]);
    assert (page_resp_ready == dut.s0_enq_stage_ready);
    assert (req_ready_a[0] ==
            (!dut.s0_valid[0] ||
             (dut.s0_valid[0] && dut.s0_hit[0] && dut.s0_port_ready[0])));
end: p_memory_combinational

always_ff @(posedge clk) begin: p_memory_sequential
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if ($past(req_ready_a[0])) begin
            assert (dut.s0_valid[0] == $past(req_valid));
            if ($past(req_valid)) begin
                assert (dut.s0_req[0].addr == $past(req_addr));
                assert (dut.s0_req[0].we == $past(req_we));
                assert (dut.s0_req[0].thrd == $past(req_thrd));
                assert (dut.s0_req[0].wstrb == $past(req_wstrb));
                assert (dut.s0_req[0].wdata == $past(req_wdata));
            end
        end
        if ($past(page_req_valid && !page_req_ready))
            assert (page_req_valid);
        if ($past(page_transfer_done))
            assert (page_completion_pending);
        if ($past(page_req_valid && page_req_ready && !page_transfer_done)) begin
            assert (!page_completion_pending);
            assert (page_completion_thrd == $past(dut.r_page_req_thrd));
        end
        for (int b = 0; b < NUM_BANKS; b++)
            assert (!(dut.r_chosen_valid[b] && !dut.w_bank_chosen[b] &&
                      dut.w_mem_resp_ready[b]));
    end
end: p_memory_sequential
