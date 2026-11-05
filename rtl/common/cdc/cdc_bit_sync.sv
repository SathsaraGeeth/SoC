`default_nettype none

module cdc_bit_sync #(
    parameter int unsigned STAGES = 2,
    parameter logic RESET_VALUE = 1'b0
) (
    input  logic i_dst_clk,
    input  logic i_dst_rst_n,
    input  logic i_async,
    output logic o_sync
);
    (* async_reg = "true" *) logic [STAGES-1:0] sync_ff;

    initial assert (STAGES >= 2);

    always_ff @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if (!i_dst_rst_n)
            sync_ff <= {STAGES{RESET_VALUE}};
        else
            sync_ff <= {sync_ff[STAGES-2:0], i_async};
    end

    assign o_sync = sync_ff[STAGES-1];
endmodule

`default_nettype wire
