always_comb begin:p_sys_ready
 assert(req_ready==(!dut.r_mmio_resp_valid&&
                   (!dut.r_owned||((64'(host_thrd)==dut.r_owner_thrd)&&
                                   dut.w_cmd_enq_ready&&!dut.r_wb_valid))));
 if(dut.r_owned&&64'(host_thrd)!=dut.r_owner_thrd)assert(!req_ready);
end:p_sys_ready
always_ff@(posedge clk)begin:p_sys_seq
 if(f_past_valid&&rst_n&&$past(rst_n))begin
  if($past(resp_valid&&!resp_ready))begin assert(resp_valid);assert(resp_rdata==$past(resp_rdata));end
  if($past(req_valid&&req_ready))assert(resp_valid);
  if($past(req_valid&&req_ready&&req_addr[7:0]==8'h08&&req_wmask!='0))begin
   assert(dut.r_cmd=={$past(req_wdata),$past(dut.r_cmd[255:64])});
   if($past(dut.r_cmd_word_cnt)==3)assert(dut.r_cmd_word_cnt=='0);
   else assert(dut.r_cmd_word_cnt==$past(dut.r_cmd_word_cnt)+1'b1);
  end
  if($past(dut.w_r_cmd_valid&&sys_cnfg_pkg::is_cmd_delegation(dut.r_cmd)))begin
   assert(dut.r_owned);assert(dut.r_owner_thrd==$past(sys_cnfg_pkg::get_cmd_tid(dut.r_cmd)));
  end
  if($past(dut.w_r_cmd_valid&&sys_cnfg_pkg::is_cmd_release(dut.r_cmd)))assert(!dut.r_owned);
  if($past(dut.r_owned)&&!$past(dut.w_r_cmd_valid))begin assert(dut.r_owned);assert(dut.r_owner_thrd==$past(dut.r_owner_thrd));end
 end
end:p_sys_seq
