/* P2--- instruction requests select exactly their decoded direction. */
always_comb begin: p_instruction_route
    assert (o_req_instr_ready ==
            (i_mem_req_instr_ready[dut.instr_dir] &&
             dut.instr_rob_enq_ready && dut.instr_valid_dir));
    for (int direction = 0; direction < 4; direction++) begin
        assert (o_mem_req_instr_valid[direction] ==
                (i_req_instr_valid && dut.instr_rob_enq_ready &&
                 dut.instr_valid_dir && (2'(direction) == dut.instr_dir)));
        assert (o_mem_req_instr_addr[direction] == i_req_instr_addr);
        assert (o_mem_req_instr_thrd_id[direction] == i_req_instr_thrd_id);
        assert (o_mem_req_instr_priv[direction] == i_req_instr_priv);
    end
end: p_instruction_route
/*  ---P2 */

/* P3--- data requests select either one memory direction or MMIO, never both. */
always_comb begin: p_data_route
    assert (o_mmio_req_valid ==
            (dut.data_is_mmio && i_req_data_valid && dut.data_rob_enq_ready));
    assert (o_req_data_ready ==
            (dut.data_target_ready && dut.data_rob_enq_ready &&
             (dut.data_is_mmio || dut.data_valid_dir)));
    assert (o_mmio_req_addr == i_req_data_addr);
    assert (o_mmio_req_thrd_id == i_req_data_thrd_id);
    assert (o_mmio_req_priv == i_req_data_priv);
    assert (o_mmio_req_rw == i_req_data_rw);
    assert (o_mmio_req_wstrb == i_req_data_wstrb);
    assert (o_mmio_req_wdata == i_req_data_wdata);
    for (int direction = 0; direction < 4; direction++) begin
        assert (o_mem_req_data_valid[direction] ==
                (!dut.data_is_mmio && i_req_data_valid &&
                 dut.data_rob_enq_ready && dut.data_valid_dir &&
                 (2'(direction) == dut.data_dir)));
        assert (o_mem_req_data_addr[direction] == i_req_data_addr);
        assert (o_mem_req_data_thrd_id[direction] == i_req_data_thrd_id);
        assert (o_mem_req_data_priv[direction] == i_req_data_priv);
        assert (o_mem_req_data_rw[direction] == i_req_data_rw);
        assert (o_mem_req_data_lq[direction] == i_req_data_lq);
        assert (o_mem_req_data_sc[direction] == i_req_data_sc);
        assert (o_mem_req_data_wstrb[direction] == i_req_data_wstrb);
        assert (o_mem_req_data_wdata[direction] == i_req_data_wdata);
    end
end: p_data_route
/*  ---P3 */
