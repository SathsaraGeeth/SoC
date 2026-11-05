/* P4--- core page messages use the local East memory direction at C_X=0. */
always_comb begin: p_outbound_page_message
    assert (o_core_page_msg_ready == i_mem_page_msg_ready[1]);
    for (int direction = 0; direction < 4; direction++) begin
        assert (o_mem_page_msg_valid[direction] ==
                (i_core_page_msg_valid && direction == 1));
        assert (o_mem_page_msg[direction] == i_core_page_msg);
    end
end: p_outbound_page_message
/*  ---P4 */

/* P5--- incoming page channels preserve the fixed W/S/E/N priority. */
always_comb begin: p_inbound_page_priority
    if (i_mem_page_msg_instr_valid[3]) begin
        assert (dut.w_page_instr_valid);
        assert (dut.w_page_instr == i_mem_page_msg_instr[3]);
        assert (o_mem_page_msg_instr_ready[3] == dut.w_page_instr_ready);
    end else if (i_mem_page_msg_instr_valid[2]) begin
        assert (dut.w_page_instr == i_mem_page_msg_instr[2]);
        assert (o_mem_page_msg_instr_ready[2] == dut.w_page_instr_ready);
    end else if (i_mem_page_msg_instr_valid[1]) begin
        assert (dut.w_page_instr == i_mem_page_msg_instr[1]);
        assert (o_mem_page_msg_instr_ready[1] == dut.w_page_instr_ready);
    end else if (i_mem_page_msg_instr_valid[0]) begin
        assert (dut.w_page_instr == i_mem_page_msg_instr[0]);
        assert (o_mem_page_msg_instr_ready[0] == dut.w_page_instr_ready);
    end else begin
        assert (!dut.w_page_instr_valid);
    end

    if (i_mem_page_msg_data_valid[3]) begin
        assert (dut.w_page_data_valid);
        assert (dut.w_page_data == i_mem_page_msg_data[3]);
        assert (o_mem_page_msg_data_ready[3] == dut.w_page_data_ready);
    end else if (i_mem_page_msg_data_valid[2]) begin
        assert (dut.w_page_data == i_mem_page_msg_data[2]);
        assert (o_mem_page_msg_data_ready[2] == dut.w_page_data_ready);
    end else if (i_mem_page_msg_data_valid[1]) begin
        assert (dut.w_page_data == i_mem_page_msg_data[1]);
        assert (o_mem_page_msg_data_ready[1] == dut.w_page_data_ready);
    end else if (i_mem_page_msg_data_valid[0]) begin
        assert (dut.w_page_data == i_mem_page_msg_data[0]);
        assert (o_mem_page_msg_data_ready[0] == dut.w_page_data_ready);
    end else begin
        assert (!dut.w_page_data_valid);
    end
end: p_inbound_page_priority
/*  ---P5 */
