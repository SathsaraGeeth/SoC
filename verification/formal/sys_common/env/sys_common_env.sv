/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara
*/

`default_nettype none
module sys_common_formal (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic clr_n,
    input logic start,
    input logic sel,
    input logic [7:0] data0,
    input logic [7:0] data1,
    input logic [2:0] ptr,
    input logic [7:0] target
);
    logic [7:0] reg_out, mux_out, pipe_out, pipe1_out, pipev_out;
    logic [15:0] mul_out, add_out;
    logic done;
    logic f_past_valid = 1'b0;
    logic f_initial = 1'b0;
    logic [7:0] m_reg;
    logic [7:0] m_pipe [2];
    logic [7:0] m_pipev [5];
    logic [2:0] m_ptr;
    logic [2:0] m_sel_ptr;
    logic [15:0] m_mul;
    logic [15:0] m_add;
    logic [7:0] m_count;

    register #(.WIDTH(8)) u_register(
        .i_clk(clk), .i_rst_n(rst_n), .i_clr_n(clr_n), .i_en(en),
        .i_data(data0), .o_data(reg_out));
    mux2 #(.WIDTH(8)) u_mux(
        .i_sel(sel), .i_data0(data0), .i_data1(data1), .o_data(mux_out));
    delayed_pipe #(.WIDTH(8), .DEPTH(2)) u_pipe(
        .i_clk(clk), .i_rst_n(rst_n), .i_en(en), .i_clr_n(clr_n),
        .i_in(data0), .o_out(pipe_out));
    delayed_pipe #(.WIDTH(8), .DEPTH(1)) u_pipe1(
        .i_clk(clk), .i_rst_n(rst_n), .i_en(en), .i_clr_n(clr_n),
        .i_in(data0), .o_out(pipe1_out));
    mul_lat1 #(.IN_WIDTH(8)) u_mul(
        .i_clk(clk), .i_rst_n(rst_n), .i_clr_n(clr_n), .i_en(en),
        .i_data0(data0), .i_data1(data1), .o_data(mul_out));
    add_lat1 #(.IN_WIDTH(8)) u_add(
        .i_clk(clk), .i_rst_n(rst_n), .i_clr_n(clr_n), .i_en(en),
        .i_data0(data0), .i_data1(data1), .o_data(add_out));
    delayed_pipev #(.WIDTH(8), .DEPTH(4), .M(4)) u_pipev(
        .i_clk(clk), .i_rst_n(rst_n), .i_en(en), .i_clr_n(clr_n),
        .i_in(data0), .i_ptr(ptr), .o_out(pipev_out));
    ctr #(.WIDTH(8)) u_ctr(
        .i_clk(clk), .i_rst_n(rst_n), .i_start(start), .i_en(en),
        .i_target(target), .o_done(done));

    always_ff @(posedge clk)
        f_initial <= 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        logic signed [7:0] s0, s1;
        logic signed [15:0] e0, e1;
        if (!rst_n) begin
            f_past_valid <= 1'b0;
            m_reg <= '0;
            m_pipe <= '{default:'0};
            m_pipev <= '{default:'0};
            m_ptr <= '0;
            m_sel_ptr <= '0;
            m_mul <= '0;
            m_add <= '0;
            m_count <= '0;
        end else begin
            f_past_valid <= 1'b1;
            if (!clr_n) begin
                m_reg <= '0;
                m_pipe <= '{default:'0};
                for (int stage = 1; stage <= 4; stage++)
                    m_pipev[stage] <= '0;
                m_mul <= '0;
                m_add <= '0;
            end else if (en) begin
                s0 = data0;
                s1 = data1;
                e0 = s0;
                e1 = s1;
                m_reg <= data0;
                m_pipe[0] <= data0;
                m_pipe[1] <= m_pipe[0];
                m_pipev[1] <= data0;
                m_pipev[2] <= m_pipev[1];
                m_pipev[3] <= m_pipev[2];
                m_pipev[4] <= m_pipev[3];
                m_mul <= s0 * s1;
                m_add <= e0 + e1;
            end
            m_pipev[0] <= data0;
            if (en) begin
                m_sel_ptr <= m_ptr;
                m_ptr <= ptr;
            end
            if (start)
                m_count <= '0;
            else if (en && m_count != target)
                m_count <= m_count + 1'b1;
        end
    end

    `include "sys_common_assumptions.sv"
    `include "sys_common_reset.sv"
    `include "sys_common_datapath.sv"
    `include "sys_common_coverpoints.sv"
endmodule: sys_common_formal
`default_nettype wire
