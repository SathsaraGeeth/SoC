`default_nettype none

module cdc_pulse_sync #(
    parameter int unsigned STAGES = 2
) (
    input  logic i_src_clk,
    input  logic i_src_rst_n,
    input  logic i_src_pulse,
    input  logic i_dst_clk,
    input  logic i_dst_rst_n,
    output logic o_dst_pulse
);
    logic src_toggle;
    logic dst_toggle;
    logic dst_toggle_q;

    always_ff @(posedge i_src_clk or negedge i_src_rst_n) begin
        if (!i_src_rst_n)
            src_toggle <= 1'b0;
        else if (i_src_pulse)
            src_toggle <= ~src_toggle;
    end

    cdc_bit_sync #(.STAGES(STAGES)) u_toggle_sync (
        .i_dst_clk(i_dst_clk), .i_dst_rst_n(i_dst_rst_n),
        .i_async(src_toggle), .o_sync(dst_toggle)
    );

    always_ff @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if (!i_dst_rst_n)
            dst_toggle_q <= 1'b0;
        else
            dst_toggle_q <= dst_toggle;
    end

    assign o_dst_pulse = dst_toggle ^ dst_toggle_q;
endmodule

`default_nettype wire
