module reset_sync_properties (
    input logic clk,
    input logic async_rst_n,
    input logic sync_rst_n
);
    logic past_valid;
    initial past_valid = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!async_rst_n)
            assert (!sync_rst_n);
        if (past_valid && !$past(async_rst_n))
            assert (!sync_rst_n);
    end
endmodule
