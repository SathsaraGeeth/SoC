`default_nettype none

module reset_sync #(
    parameter int unsigned STAGES = 2
) (
    input  logic i_clk,
    input  logic i_async_rst_n,
    output logic o_rst_n
);
    (* async_reg = "true" *) logic [STAGES-1:0] reset_ff;

    initial assert (STAGES >= 2);

    always_ff @(posedge i_clk or negedge i_async_rst_n) begin
        if (!i_async_rst_n)
            reset_ff <= '0;
        else
            reset_ff <= {reset_ff[STAGES-2:0], 1'b1};
    end

    assign o_rst_n = reset_ff[STAGES-1];
endmodule

`default_nettype wire
