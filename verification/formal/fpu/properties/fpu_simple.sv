always_ff @(posedge clk) begin: p_fpu_simple
    if (rst_n && f_past_valid
     && $past(rst_n && dut.w_accept && dut.w_is_simple)) begin
        assert (res_valid);
        assert (res_thrd_id == $past(issued_instr.thrd_id));
        assert (result == $past(dut.w_simple_result));
        assert (!dut.r_busy);
    end
end: p_fpu_simple
