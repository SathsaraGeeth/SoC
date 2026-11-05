module handshake_properties #(
    parameter int unsigned WIDTH = 1
) (
    input logic             src_clk,
    input logic             src_rst_n,
    input logic             req,
    input logic             ack,
    input logic [WIDTH-1:0] data
);
    logic waiting;
    logic [WIDTH-1:0] held_data;
    always_ff @(posedge src_clk) begin
        if (!src_rst_n) begin
            waiting   <= 1'b0;
            held_data <= '0;
        end else begin
            if (req && !waiting) begin
                waiting   <= 1'b1;
                held_data <= data;
            end
            if (waiting) begin
                assert (data == held_data);
                if (ack)
                    waiting <= 1'b0;
            end
        end
    end
endmodule
