always_ff@(posedge clk)begin:p_sys_reset
 if(f_past_valid&&!$past(rst_n))begin
  assert(dut.r_cmd=='0);assert(dut.r_cmd_word_cnt=='0);assert(!dut.r_cmd_done);
  assert(!dut.r_owned);assert(dut.r_owner_thrd=='0);assert(!resp_valid);
  assert(resp_rdata=='0);assert(!intr);assert(intr_thrd=='0);
 end
end:p_sys_reset

