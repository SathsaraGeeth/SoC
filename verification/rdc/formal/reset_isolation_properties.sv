module reset_isolation_properties #(
    parameter int unsigned WIDTH = 1,
    parameter logic [WIDTH-1:0] ISOLATION_VALUE = '0
) (
    input logic             clk,
    input logic             domain_rst_n,
    input logic             isolation_enable,
    input logic [WIDTH-1:0] domain_output
);
    always_ff @(posedge clk)
        if (!domain_rst_n || isolation_enable)
            assert (domain_output == ISOLATION_VALUE);
endmodule
