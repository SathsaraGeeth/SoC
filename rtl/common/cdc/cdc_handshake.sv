`default_nettype none

module cdc_handshake #(
    parameter int unsigned WIDTH = 1,
    parameter int unsigned STAGES = 2
) (
    input  logic             i_src_clk,
    input  logic             i_src_rst_n,
    input  logic [WIDTH-1:0] i_src_data,
    input  logic             i_src_valid,
    output logic             o_src_ready,
    input  logic             i_dst_clk,
    input  logic             i_dst_rst_n,
    output logic [WIDTH-1:0] o_dst_data,
    output logic             o_dst_valid,
    input  logic             i_dst_ready
);
    logic [WIDTH-1:0] held_data;
    logic req_toggle;
    logic ack_toggle;
    logic req_sync;
    logic ack_sync;

    assign o_src_ready = (ack_sync == req_toggle);

    always_ff @(posedge i_src_clk or negedge i_src_rst_n) begin
        if (!i_src_rst_n) begin
            held_data  <= '0;
            req_toggle <= 1'b0;
        end else if (i_src_valid && o_src_ready) begin
            held_data  <= i_src_data;
            req_toggle <= ~req_toggle;
        end
    end

    cdc_bit_sync #(.STAGES(STAGES)) u_req_sync (
        .i_dst_clk(i_dst_clk), .i_dst_rst_n(i_dst_rst_n),
        .i_async(req_toggle), .o_sync(req_sync)
    );
    cdc_bit_sync #(.STAGES(STAGES)) u_ack_sync (
        .i_dst_clk(i_src_clk), .i_dst_rst_n(i_src_rst_n),
        .i_async(ack_toggle), .o_sync(ack_sync)
    );

    always_ff @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if (!i_dst_rst_n) begin
            o_dst_data  <= '0;
            o_dst_valid <= 1'b0;
            ack_toggle  <= 1'b0;
        end else begin
            if (!o_dst_valid && (req_sync != ack_toggle)) begin
                o_dst_data  <= held_data;
                o_dst_valid <= 1'b1;
            end
            if (o_dst_valid && i_dst_ready) begin
                o_dst_valid <= 1'b0;
                ack_toggle  <= req_sync;
            end
        end
    end
endmodule

`default_nettype wire
