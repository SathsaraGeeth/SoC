module reset_order_properties (
    input logic clk,
    input logic prerequisite_rst_n,
    input logic dependent_rst_n
);
    always_ff @(posedge clk)
        if (dependent_rst_n)
            assert (prerequisite_rst_n);
endmodule
