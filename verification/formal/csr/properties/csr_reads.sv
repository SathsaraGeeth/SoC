/* P2: Architectural read-only CSR views are exact. */
always_ff @(posedge clk) begin: p_csr_read_views
    if (rst_n) begin
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            if (rs1_addr_vec[t] == CSR_THREAD_ID)
                assert (rs1_data_vec[t] == thread_id_vec[t]);
            if (rs1_addr_vec[t] == CSR_MIP)
                assert (rs1_data_vec[t] ==
                        isa_pkg::csr_mip_from_mtip(irq_timer_vec[t]));
            if (rs1_addr_vec[t] == CSR_SIP)
                assert (rs1_data_vec[t] == '0);
            assert (medeleg_vec[t] ==
                    dut.w_bank_rdata_vec[CSR_MEDELEG][t]);
            assert (mideleg_vec[t] ==
                    dut.w_bank_rdata_vec[CSR_MIDELEG][t]);
        end
    end
end: p_csr_read_views

/* P3: Pending interrupt output exactly follows delegation and enable state. */
always_ff @(posedge clk) begin: p_csr_irq
    if (rst_n) begin
        for (int t = 0; t < NUM_HW_THRDS; t++) begin
            assert (irq_pending_vec[t] ==
                (irq_timer_vec[t] &&
                 (dut.w_bank_rdata_vec[CSR_MIDELEG][t][isa_pkg::CSR_MIE_MTIE_BIT]
                  ? (dut.w_bank_rdata_vec[CSR_SIE][t][isa_pkg::CSR_MIE_MTIE_BIT]
                     && ((dut.r_priv[t] == isa_pkg::PRIV_MODE_U)
                         || ((dut.r_priv[t] == isa_pkg::PRIV_MODE_S)
                             && dut.r_sie[t])))
                  : (dut.w_bank_rdata_vec[CSR_MIE][t][isa_pkg::CSR_MIE_MTIE_BIT]
                     && ((dut.r_priv[t] != isa_pkg::PRIV_MODE_M)
                         || dut.r_mie[t])))));
        end
    end
end: p_csr_irq

