`timescale 1ns/1ps

module uart_rx_smoke_tb;
    logic clk = 0;
    logic rst_n = 0;
    logic rx = 1;
    logic [7:0] rx_data;
    logic rx_ready;
    logic rx_empty;

    always #1 clk = !clk;
    always @(posedge clk) begin
        if (dut.w_s_rx_data_valid)
            $display("sample state=%0d bit=%0b shift=%02h", dut.s_rx_state,
                     dut.w_s_rx_data, dut.w_p_rx_data);
        if (dut.w_p_rx_data_valid)
            $display("enqueue data=%02h", dut.w_p_rx_data);
    end

    uart #(
        .RX_DEPTH(8),
        .TX_DEPTH(8),
        .PARITY_EN(0),
        .EN_2STOP_BITS(0)
    ) dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_baud_div(32'd64),
        .o_deq_rx_data(rx_data),
        .o_deq_rx_ready(rx_ready),
        .i_deq_rx_valid(1'b0),
        .o_rx_full(),
        .o_rx_empty(rx_empty),
        .o_rx_level(),
        .i_enq_tx_data('0),
        .i_enq_tx_valid(1'b0),
        .o_enq_tx_ready(),
        .o_tx_full(),
        .o_tx_empty(),
        .o_tx_level(),
        .i_rx(rx),
        .o_tx()
    );

    task automatic drive_bit(input logic value);
        rx = value;
        repeat (64) @(posedge clk);
    endtask

    initial begin
        logic [7:0] test_data;
        test_data = 8'h68;
        repeat (8) @(posedge clk);
        rst_n = 1;
        repeat (100) @(posedge clk);
        drive_bit(1'b0);
        for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
            drive_bit(test_data[bit_idx]);
        end
        drive_bit(1'b1);
        repeat (200) @(posedge clk);
        if (rx_empty || !rx_ready || rx_data != 8'h68) begin
            $fatal(1, "RX failed: empty=%0b ready=%0b data=%02h",
                   rx_empty, rx_ready, rx_data);
        end
        $display("UART_RX_SMOKE_PASS data=%02h", rx_data);
        $finish;
    end
endmodule
