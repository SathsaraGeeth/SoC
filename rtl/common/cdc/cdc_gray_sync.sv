`default_nettype none

module cdc_gray_sync #(
    parameter int unsigned WIDTH = 2,
    parameter int unsigned STAGES = 2
) (
    input  logic             i_dst_clk,
    input  logic             i_dst_rst_n,
    input  logic [WIDTH-1:0] i_async_gray,
    output logic [WIDTH-1:0] o_sync_gray
);
    (* async_reg = "true" *) logic [WIDTH-1:0] sync_ff [STAGES];

    initial begin
        assert (WIDTH >= 2);
        assert (STAGES >= 2);
    end

    always_ff @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if (!i_dst_rst_n) begin
            for (int unsigned stage = 0; stage < STAGES; stage++)
                sync_ff[stage] <= '0;
        end else begin
            sync_ff[0] <= i_async_gray;
            for (int unsigned stage = 1; stage < STAGES; stage++)
                sync_ff[stage] <= sync_ff[stage-1];
        end
    end

    assign o_sync_gray = sync_ff[STAGES-1];
endmodule

`default_nettype wire
