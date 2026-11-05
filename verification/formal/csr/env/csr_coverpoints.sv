always_ff @(posedge clk) begin: c_csr_activity
    cover (rst_n && we && rd_addr == CSR_MSTATUS);
    cover (rst_n && trap_we && !trap_to_s);
    cover (rst_n && trap_we && trap_to_s);
    cover (rst_n && mret_we);
    cover (rst_n && sret_we);
    cover (rst_n && |irq_pending_vec);
end: c_csr_activity

