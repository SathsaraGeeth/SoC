module async_fifo_properties (
    input logic wr_clk,
    input logic wr_rst_n,
    input logic wr_valid,
    input logic wr_ready,
    input logic rd_clk,
    input logic rd_rst_n,
    input logic rd_valid,
    input logic rd_ready
);
    logic rd_past_valid;
    initial rd_past_valid = 1'b0;
    always_ff @(posedge rd_clk) begin
        rd_past_valid <= 1'b1;
        if (rd_past_valid && rd_rst_n && $past(rd_rst_n) &&
            $past(rd_valid && !rd_ready))
            assert (rd_valid);
    end

    // Keep write-side signals in the checker interface for binding to a
    // complete occupancy/reference-model proof.
    logic unused;
    assign unused = ^{wr_clk, wr_rst_n, wr_valid, wr_ready};
endmodule
