`default_nettype none

module circular_buffer_formal (
    input logic       clk,
    input logic       rst_n,
    input logic       clr_n,
    input logic [7:0] enq_data,
    input logic       enq_valid,
    input logic       deq_valid
);
    localparam int DEPTH = 2;
    localparam int WIDTH = 8;

    logic [WIDTH-1:0]             head_data;
    logic                         deq_ready;
    logic                         enq_ready;
    logic                         full;
    logic                         empty;
    logic [$clog2(DEPTH+1)-1:0]   level;
    logic                         will_enq;
    logic                         will_deq;

    (* anyseq *) logic            f_sample_now;
    logic                         f_sampled;
    logic                         f_sample_pending;
    logic [WIDTH-1:0]             f_sample_data;
    logic [$clog2(DEPTH+1)-1:0]   f_older_count;

    assign will_enq = enq_ready && enq_valid;
    assign will_deq = deq_ready && deq_valid;

    circular_buffer #(
        .DEPTH           (DEPTH),
        .WIDTH           (WIDTH)
    ) dut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .o_head_data     (head_data),
        .o_deq_ready     (deq_ready),
        .i_deq_valid     (deq_valid),
        .i_enq_tail_data (enq_data),
        .i_enq_valid     (enq_valid),
        .o_enq_ready     (enq_ready),
        .o_full          (full),
        .o_empty         (empty),
        .o_level         (level),
        .i_clr_n         (clr_n)
    );

    logic f_past_valid = 1'b0;
    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_sampled        <= 1'b0;
            f_sample_pending <= 1'b0;
            f_sample_data    <= '0;
            f_older_count    <= '0;
        end else if (!clr_n) begin
            f_sampled        <= 1'b0;
            f_sample_pending <= 1'b0;
            f_sample_data    <= '0;
            f_older_count    <= '0;
        end else begin
            if (!f_sampled && f_sample_now && will_enq) begin
                f_sampled        <= 1'b1;
                f_sample_pending <= 1'b1;
                f_sample_data    <= enq_data;
                f_older_count    <= level - $bits(level)'(will_deq);
            end else if (f_sample_pending && will_deq) begin
                if (f_older_count == '0) begin
                    f_sample_pending <= 1'b0;
                end else begin
                    f_older_count <= f_older_count - 1'b1;
                end
            end
        end
    end

    `include "circular_buffer_assumptions.sv"
    `include "circular_buffer_reset.sv"
    `include "circular_buffer_status.sv"
    `include "circular_buffer_protocol.sv"
    `include "circular_buffer_data.sv"
    `include "circular_buffer_coverpoints.sv"
endmodule: circular_buffer_formal

`default_nettype wire
