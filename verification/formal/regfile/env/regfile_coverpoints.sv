// Reach basic write/read and multi-port scenarios.
always_ff @(posedge clk) begin: regfile_covers
    cover (we && (rd_addr != '0));
    cover ((rs1_addr != rs2_addr) && (rs2_addr != rs3_addr));
    cover (we && (rd_addr == rs1_addr));
    cover (we && (rd_addr == '0));
    cover (we && (wthrd_id != rthrd_id) && (rd_addr == rs1_addr));
end
