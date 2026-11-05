`default_nettype none
module uart #(
    parameter RX_DEPTH = 8, parameter TX_DEPTH = 8,
    parameter PARITY_EN = 0, parameter EN_2STOP_BITS = 0
) (
    input logic i_clk, input logic i_rst_n, input logic [31:0] i_baud_div,
    output logic [7:0] o_deq_rx_data, output logic o_deq_rx_ready,
    input logic i_deq_rx_valid, output logic o_rx_full, output logic o_rx_empty,
    output logic [$clog2(RX_DEPTH+1)-1:0] o_rx_level,
    input logic [7:0] i_enq_tx_data, input logic i_enq_tx_valid,
    output logic o_enq_tx_ready, output logic o_tx_full, output logic o_tx_empty,
    output logic [$clog2(TX_DEPTH+1)-1:0] o_tx_level,
    input logic i_rx, output logic o_tx
);
    (* anyseq *) logic [7:0] rx_data;
    (* anyseq *) logic tx_ready;
    (* anyseq *) logic [$clog2(RX_DEPTH+1)-1:0] rx_level;
    (* anyseq *) logic [$clog2(TX_DEPTH+1)-1:0] tx_level;
    assign o_deq_rx_data  = rx_data;
    assign o_deq_rx_ready = !o_rx_empty;
    assign o_rx_level     = rx_level;
    assign o_tx_level     = tx_level;
    assign o_rx_empty     = rx_level == '0;
    assign o_rx_full      = rx_level == $bits(rx_level)'(RX_DEPTH);
    assign o_tx_empty     = tx_level == '0;
    assign o_tx_full      = tx_level == $bits(tx_level)'(TX_DEPTH);
    assign o_enq_tx_ready = tx_ready && !o_tx_full;
    assign o_tx           = 1'b1;
    always_comb begin
        assume (rx_level <= $bits(rx_level)'(RX_DEPTH));
        assume (tx_level <= $bits(tx_level)'(TX_DEPTH));
    end
endmodule: uart
`default_nettype wire

