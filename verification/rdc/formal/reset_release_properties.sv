module reset_release_properties #(
    parameter int unsigned MIN_CYCLES = 2,
    localparam int unsigned COUNT_W = $clog2(MIN_CYCLES+1)
) (
    input logic clk,
    input logic async_rst_n,
    input logic sync_rst_n
);
    logic [COUNT_W-1:0] release_count;
    initial release_count = '0;
    always_ff @(posedge clk) begin
        if (!async_rst_n)
            release_count <= '0;
        else if (release_count < COUNT_W'(MIN_CYCLES))
            release_count <= release_count + 1'b1;
        if (release_count < COUNT_W'(MIN_CYCLES))
            assert (!sync_rst_n);
    end
endmodule
