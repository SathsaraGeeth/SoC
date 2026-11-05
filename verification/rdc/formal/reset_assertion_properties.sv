module reset_assertion_properties (
    input logic clk,
    input logic async_rst_n,
    input logic sync_rst_n
);
    always_ff @(posedge clk)
        if (!async_rst_n)
            assert (!sync_rst_n);
endmodule
