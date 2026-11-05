always_ff@(posedge clk)begin:c_sys
 cover(rst_n&&req_valid&&req_ready&&req_addr[7:0]==0);
 cover(rst_n&&dut.r_cmd_done);
 cover(rst_n&&dut.r_owned);
 cover(rst_n&&dut.r_owned&&host_thrd!=dut.r_owner_thrd&&!req_ready);
 cover(rst_n&&intr);
end:c_sys

