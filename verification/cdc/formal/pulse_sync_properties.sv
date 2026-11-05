module pulse_sync_properties (
    input logic dst_clk,
    input logic dst_rst_n,
    input logic dst_pulse
);
    logic past_valid;
    initial past_valid = 1'b0;
    always_ff @(posedge dst_clk) begin
        past_valid <= 1'b1;
        if (!dst_rst_n)
            assert (!dst_pulse);
        if (past_valid && $past(dst_pulse))
            assert (!dst_pulse);
    end
endmodule
