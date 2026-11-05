always_ff@(posedge clk)begin
 if(!f_past_valid)assume(!rst_n);if(f_past_valid&&$past(rst_n))assume(rst_n);
 assume(host_thrd<topology_pkg::THREADS_PER_CLUSTER);
 if(req_valid&&req_ready&&req_addr[7:0]==8'h08&&req_wmask!='0&&dut.r_cmd_word_cnt=='0)
   assume(req_wdata[31:24] inside {8'h00,sys_cnfg_pkg::CMD_TYPE_III,sys_cnfg_pkg::CMD_TYPE_IV});
end

