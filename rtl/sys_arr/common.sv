/*
 * common.sv
 * 
 * Copyright (C) 2025 Sathsara Geeth
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

`timescale 1ns/1ps
`default_nettype none

// Helper Modules
module register #(
    parameter WIDTH = 8
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,
    input  logic                  i_clr_n,
    input  logic                  i_en,
    input  logic [WIDTH-1:0]      i_data,
    output logic [WIDTH-1:0]      o_data
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_data <= '0;
        end else if (!i_clr_n) begin
            o_data <= '0;
        end else if (i_en) begin
            o_data <= i_data;
        end
    end
endmodule

module mux2 #(
    parameter WIDTH = 8
    )(
    input  logic                    i_sel,
    input  logic [WIDTH-1:0]        i_data0,
    input  logic [WIDTH-1:0]        i_data1,
    output logic [WIDTH-1:0]        o_data
);
    assign o_data = i_sel ? i_data1 : i_data0;
endmodule

module delayed_pipe #(
    parameter WIDTH = 8,
    parameter DEPTH = 0
)(
    input  logic              i_clk,
    input  logic              i_rst_n,
    input  logic              i_en,
    input  logic              i_clr_n,
    input  logic [WIDTH-1:0]  i_in,
    output logic [WIDTH-1:0]  o_out
);
generate
    if (DEPTH == 0) begin
        assign o_out = i_in;
    end else begin
        logic [WIDTH-1:0] r_d [DEPTH:0];
        assign r_d[0] = i_in;
        genvar k;
        for (k = 0; k < DEPTH; k++) begin : DELAY
            register #(WIDTH) u_sr (
                .i_clk     (i_clk),
                .i_rst_n   (i_rst_n),
                .i_en      (i_en),
                .i_clr_n   (i_clr_n),
                .i_data    (r_d[k]),
                .o_data    (r_d[k+1])
            );
        end
        assign o_out = r_d[DEPTH];
    end
endgenerate
endmodule

module mul_lat1 #(
    parameter IN_WIDTH = 8
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,
    input  logic                  i_clr_n,
    input  logic                  i_en,
    input  logic [IN_WIDTH-1:0]   i_data0,
    input  logic [IN_WIDTH-1:0]   i_data1,
    output logic [2*IN_WIDTH-1:0] o_data
);
    (* use_dsp = "yes" *)
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_data <= '0;
        end else if (!i_clr_n) begin
            o_data <= '0;
        end else if (i_en) begin
            o_data <= $signed(i_data0) * $signed(i_data1);
        end
    end
endmodule

module add_lat1 #(
    parameter IN_WIDTH = 8
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,
    input  logic                  i_clr_n,
    input  logic                  i_en,
    input  logic [IN_WIDTH-1:0]   i_data0,
    input  logic [IN_WIDTH-1:0]   i_data1,
    output logic [2*IN_WIDTH-1:0] o_data
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_data <= '0;
        end else if (!i_clr_n) begin
            o_data <= '0;
        end else if (i_en) begin
            o_data <= $signed(i_data0) + $signed(i_data1);
        end
    end
endmodule

module delayed_pipev #(
    parameter WIDTH = 8,
    parameter DEPTH = 0,
    parameter M     = 4
)(
    input  logic                   i_clk,
    input  logic                   i_rst_n,
    input  logic                   i_en,
    input  logic                   i_clr_n,
    input  logic [WIDTH-1:0]       i_in,
    input  logic [$clog2(M+1)-1:0] i_ptr,
    output logic [WIDTH-1:0]       o_out
);
    generate
        if (DEPTH == 0) begin
            assign o_out = i_in;
        end else begin : gen_pipe

            logic [WIDTH-1:0]       r_d [DEPTH+1];
            logic [$clog2(M+1)-1:0] r_ptr;
            logic [DEPTH:0]         r_sel_oh;

            always_ff @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) r_ptr <= '0;
                else if (i_en) r_ptr <= i_ptr;
            end

            always_ff @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) begin
                    r_sel_oh <= (DEPTH+1)'(1);
                end else if (i_en) begin
                    r_sel_oh <= '0;
                    r_sel_oh[r_ptr] <= 1'b1;
                end
            end

            assign r_d[0] = i_in;
            genvar k;
            for (k = 0; k < DEPTH; k++) begin : DELAY
                register #(.WIDTH(WIDTH)) u_sr (
                    .i_clk   (i_clk),
                    .i_rst_n (i_rst_n),
                    .i_en    (i_en),
                    .i_clr_n (i_clr_n),
                    .i_data  (r_d[k]),
                    .o_data  (r_d[k+1])
                );
            end

            logic [WIDTH-1:0] w_out;
            always_comb begin
                w_out = '0;
                for (int i = 0; i <= DEPTH; i++)
                    w_out |= {WIDTH{r_sel_oh[i]}} & r_d[i];
            end
            assign o_out = w_out;

        end
    endgenerate
endmodule



module ctr #(
    parameter int WIDTH  = 8
)(
    input  logic             i_clk,
    input  logic             i_rst_n,
    input  logic             i_start,
    input  logic             i_en,
    input  logic [WIDTH-1:0] i_target,
    output logic             o_done
    
);
    logic [WIDTH-1:0] r_count;
    
    assign o_done = (r_count == i_target);
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_count <= '0;
        end else if (i_start) begin
            r_count <= '0;
        end else if (i_en && !o_done) begin
            r_count <= r_count + 1'b1;
        end
    end
endmodule