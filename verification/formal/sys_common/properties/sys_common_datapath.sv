/* P2-P8: Each helper equals its independent reference model. */
always_comb begin
    assert (mux_out == (sel ? data1 : data0));
    if (rst_n && f_past_valid) begin
        assert (reg_out == m_reg);
        assert (pipe1_out == m_pipe[0]);
        assert (u_pipe.gen_pipe.r_d[1] == m_pipe[0]);
        assert (u_pipe.gen_pipe.r_d[2] == m_pipe[1]);
        assert (u_pipe1.gen_pipe.r_d[1] == m_pipe[0]);
        assert (pipe_out == m_pipe[1]);
        assert (mul_out == m_mul);
        assert (add_out == m_add);
        assert (u_pipev.gen_pipe.r_ptr == m_ptr);
        assert (m_ptr <= 4);
        assert (m_sel_ptr <= 4);
        assert (u_pipev.gen_pipe.r_sel_oh == (5'b00001 << m_sel_ptr));
        assert (u_pipev.gen_pipe.r_d[1] == m_pipev[1]);
        assert (u_pipev.gen_pipe.r_d[2] == m_pipev[2]);
        assert (u_pipev.gen_pipe.r_d[3] == m_pipev[3]);
        assert (u_pipev.gen_pipe.r_d[4] == m_pipev[4]);
        unique case (m_sel_ptr)
            0: assert (pipev_out == data0);
            1: assert (pipev_out == m_pipev[1]);
            2: assert (pipev_out == m_pipev[2]);
            3: assert (pipev_out == m_pipev[3]);
            4: assert (pipev_out == m_pipev[4]);
            default: assert (1'b0);
        endcase
        assert (u_ctr.r_count == m_count);
        assert (done == (m_count == target));
    end
end

/* The second fixed-delay stage consumes the independently checked first stage. */
always_ff @(posedge clk) begin
    if (f_past_valid && rst_n && $past(rst_n)) begin
        if (!$past(clr_n))
            assert (pipe_out == '0);
        else if ($past(en))
            assert (pipe_out == $past(pipe1_out));
        else
            assert (pipe_out == $past(pipe_out));
    end
end
