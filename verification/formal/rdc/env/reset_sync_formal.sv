`default_nettype none

module reset_sync_formal;
    (* gclk *) logic clk;
    (* anyseq *) logic async_rst_n;
    logic sync_rst_n;
    logic past_valid = 1'b0;

    reset_sync #(.STAGES(2)) dut (
        .i_clk(clk),
        .i_async_rst_n(async_rst_n),
        .o_rst_n(sync_rst_n)
    );

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!async_rst_n)
            assert (!sync_rst_n);
        if (past_valid && !$past(async_rst_n))
            assert (!sync_rst_n);
        if (past_valid && $rose(sync_rst_n))
            assert (async_rst_n && $past(async_rst_n));
    end
endmodule

`default_nettype wire
