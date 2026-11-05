`timescale 1ns/1ps
`default_nettype none

module buff_mem #(
    parameter DEPTH = 8,
    parameter WIDTH = 8
) (
    input  logic                     i_clk,
    input  logic                     i_we,
    input  logic [$clog2(DEPTH)-1:0] i_wr_addr,
    input  logic [WIDTH-1:0]         i_din,
    input  logic [$clog2(DEPTH)-1:0] i_rd_addr,
    output logic [WIDTH-1:0]         o_dout
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge i_clk) begin
        if (i_we) begin
            mem[i_wr_addr] <= i_din;
        end
    end

    always_ff @(posedge i_clk) begin
        o_dout <= mem[i_rd_addr];
    end
endmodule: buff_mem


module circular_buffer #(
    parameter  DEPTH            = 8,
    parameter  WIDTH            = 8
) (
    input   logic                           i_clk,
    input   logic                           i_rst_n,
    output  logic   [WIDTH-1:0]             o_head_data,
    output  logic                           o_deq_ready,
    input   logic                           i_deq_valid,    
    input   logic   [WIDTH-1:0]             i_enq_tail_data,
    input   logic                           i_enq_valid,
    output  logic                           o_enq_ready,
    output  logic                           o_full,
    output  logic                           o_empty,
    output  logic   [$clog2(DEPTH+1)-1:0]   o_level,
    input   logic                           i_clr_n
);  

    logic   [$clog2(DEPTH)-1:0]         r_head_ptr, r_tail_ptr;
    logic   [$clog2(DEPTH+1)-1:0]       r_count;
    logic   [$clog2(DEPTH)-1:0]         w_next_head_ptr;
    logic   [$clog2(DEPTH+1)-1:0]       w_next_count;
    logic                               w_will_enq, w_will_deq;
    logic   [WIDTH-1:0]                 w_buff_mem_out;
    logic                               r_bypass_en;
    logic   [WIDTH-1:0]                 r_bypass_data;

    assign w_will_enq = o_enq_ready & i_enq_valid;
    assign w_will_deq = o_deq_ready & i_deq_valid;

    always_comb begin
        o_full      = (r_count == ($clog2(DEPTH+1))'(DEPTH));
        o_empty     = (r_count == '0);
        o_level     = r_count;
        o_enq_ready = !o_full;
    end

    always_comb begin
        if (w_will_deq) begin
            w_next_head_ptr = r_head_ptr + 1'b1;
        end else begin
            w_next_head_ptr = r_head_ptr;
        end
    end

    buff_mem #(
        .DEPTH     (DEPTH),
        .WIDTH     (WIDTH)
    ) u_buff_mem (
        .i_clk     (i_clk),
        .i_we      (w_will_enq),
        .i_wr_addr (r_tail_ptr),
        .i_din     (i_enq_tail_data),
        .i_rd_addr (w_next_head_ptr),
        .o_dout    (w_buff_mem_out)
    );

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_bypass_en   <= 1'b0;
            r_bypass_data <= '0;
        end else if (!i_clr_n) begin
            r_bypass_en   <= 1'b0;
            r_bypass_data <= '0;
        end else begin
            r_bypass_en   <= w_will_enq && (r_tail_ptr == w_next_head_ptr);
            r_bypass_data <= i_enq_tail_data;
        end
    end

    assign o_head_data = r_bypass_en ? r_bypass_data : w_buff_mem_out;

    always_comb begin
        case ({w_will_enq, w_will_deq})
            2'b01:   w_next_count = r_count - 1'b1;
            2'b10:   w_next_count = r_count + 1'b1;
            default: w_next_count = r_count; 
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_head_ptr  <= '0;
            r_tail_ptr  <= '0;
            r_count     <= '0;
            o_deq_ready <= 1'b0;
        end else if (!i_clr_n) begin
            r_head_ptr  <= '0;
            r_tail_ptr  <= '0;
            r_count     <= '0;
            o_deq_ready <= 1'b0;
        end else begin
            r_count     <= w_next_count;
            o_deq_ready <= (w_next_count != '0); 

            case ({w_will_enq, w_will_deq})
                2'b01:   r_head_ptr <= r_head_ptr + 1'b1;
                2'b10:   r_tail_ptr <= r_tail_ptr + 1'b1;
                2'b11: begin
                    r_head_ptr <= r_head_ptr + 1'b1;
                    r_tail_ptr <= r_tail_ptr + 1'b1;
                end
                default: begin end
            endcase
        end
    end
endmodule: circular_buffer
