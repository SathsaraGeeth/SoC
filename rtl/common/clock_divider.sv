`default_nettype none

module clock_divider #(
    parameter int unsigned DIVIDE = 2,
    localparam int unsigned COUNT_W = $clog2(DIVIDE)
) (
    input  logic i_clk,
    input  logic i_rst_n,
    output logic o_clk
);
    logic [COUNT_W-1:0] count;

    initial begin
        assert (DIVIDE >= 2);
        assert ((DIVIDE & (DIVIDE - 1)) == 0);
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            count <= '0;
        else
            count <= count + 1'b1;
    end

    assign o_clk = count[COUNT_W-1];
endmodule

`default_nettype wire
