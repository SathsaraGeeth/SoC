`default_nettype none

module async_fifo #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned DEPTH = 4,
    parameter int unsigned STAGES = 2,
    localparam int unsigned ADDR_W = $clog2(DEPTH)
) (
    input  logic             i_wr_clk,
    input  logic             i_wr_rst_n,
    input  logic [WIDTH-1:0] i_wr_data,
    input  logic             i_wr_valid,
    output logic             o_wr_ready,
    input  logic             i_rd_clk,
    input  logic             i_rd_rst_n,
    output logic [WIDTH-1:0] o_rd_data,
    output logic             o_rd_valid,
    input  logic             i_rd_ready
);
    logic [WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0] wr_bin, rd_bin;
    logic [ADDR_W:0] wr_gray, rd_gray;
    logic [ADDR_W:0] wr_gray_sync, rd_gray_sync;
    logic [ADDR_W:0] wr_bin_next, rd_bin_next;
    logic [ADDR_W:0] wr_gray_next, rd_gray_next;
    logic fifo_full_next, fifo_empty_next;
    logic fifo_full, fifo_empty;

    initial begin
        assert (DEPTH >= 4);
        assert ((DEPTH & (DEPTH - 1)) == 0);
    end

    assign wr_bin_next  = wr_bin + (ADDR_W+1)'(i_wr_valid && o_wr_ready);
    assign rd_bin_next  = rd_bin + (ADDR_W+1)'(o_rd_valid && i_rd_ready);
    assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
    assign fifo_empty_next = (rd_gray_next == wr_gray_sync);
    assign fifo_full_next  = (wr_gray_next ==
                              {~rd_gray_sync[ADDR_W:ADDR_W-1],
                               rd_gray_sync[ADDR_W-2:0]});
    assign o_wr_ready   = !fifo_full;
    assign o_rd_valid   = !fifo_empty;
    assign o_rd_data    = mem[rd_bin[ADDR_W-1:0]];

    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
            fifo_full <= 1'b0;
        end else begin
            if (i_wr_valid && o_wr_ready)
                mem[wr_bin[ADDR_W-1:0]] <= i_wr_data;
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
            fifo_full <= fifo_full_next;
        end
    end

    always_ff @(posedge i_rd_clk or negedge i_rd_rst_n) begin
        if (!i_rd_rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
            fifo_empty <= 1'b1;
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
            fifo_empty <= fifo_empty_next;
        end
    end

    cdc_gray_sync #(.WIDTH(ADDR_W + 1), .STAGES(STAGES)) u_wr_ptr_sync (
        .i_dst_clk(i_rd_clk), .i_dst_rst_n(i_rd_rst_n),
        .i_async_gray(wr_gray), .o_sync_gray(wr_gray_sync)
    );
    cdc_gray_sync #(.WIDTH(ADDR_W + 1), .STAGES(STAGES)) u_rd_ptr_sync (
        .i_dst_clk(i_wr_clk), .i_dst_rst_n(i_wr_rst_n),
        .i_async_gray(rd_gray), .o_sync_gray(rd_gray_sync)
    );
endmodule

`default_nettype wire
