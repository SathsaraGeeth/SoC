`default_nettype none

module cdc_handshake_formal;
    localparam int WIDTH = 8;
    (* gclk *) logic src_clk;
    (* gclk *) logic dst_clk;
    (* anyseq *) logic [WIDTH-1:0] src_data;
    (* anyseq *) logic src_valid;
    (* anyseq *) logic dst_ready;
    logic src_rst_n = 1'b0;
    logic dst_rst_n = 1'b0;
    logic src_ready;
    logic [WIDTH-1:0] dst_data;
    logic dst_valid;

    cdc_handshake #(.WIDTH(WIDTH)) dut (
        .i_src_clk(src_clk), .i_src_rst_n(src_rst_n),
        .i_src_data(src_data), .i_src_valid(src_valid),
        .o_src_ready(src_ready),
        .i_dst_clk(dst_clk), .i_dst_rst_n(dst_rst_n),
        .o_dst_data(dst_data), .o_dst_valid(dst_valid),
        .i_dst_ready(dst_ready)
    );

    always_ff @(posedge src_clk) begin
        src_rst_n <= 1'b1;
        if (src_rst_n) begin
            if (src_valid && !src_ready)
                assume ($stable(src_data));
        end
    end

    always_ff @(posedge dst_clk) begin
        dst_rst_n <= 1'b1;
        if (dst_rst_n) begin
            if ($past(dst_rst_n && dst_valid && !dst_ready)) begin
                assert (dst_valid);
                assert ($stable(dst_data));
            end
        end
    end
endmodule

`default_nettype wire
