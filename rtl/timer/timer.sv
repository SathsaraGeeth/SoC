`timescale 1ns/1ps
`default_nettype none

module timer (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         req_valid_i,
    input  logic [63:0]  req_addr_i,
    input  logic         req_we_i,
    input  logic [7:0]   req_wstrb_i,
    input  logic [63:0]  req_wdata_i,
    output logic         req_ready_o,
    output logic         resp_valid_o,
    input  logic         resp_ready_i,
    output logic [63:0]  resp_rdata_o,
    output logic         irq_timer_o
);

    logic [63:0] mtime_q;
    logic [63:0] mtimecmp_q;

    function automatic logic [31:0] apply_wstrb32(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [3:0]  write_strobe
    );
        logic [31:0] result;
        result = old_value;
        for (int byte_index = 0; byte_index < 4; byte_index++) begin
            if (write_strobe[byte_index])
                result[byte_index * 8 +: 8] = new_value[byte_index * 8 +: 8];
        end
        return result;
    endfunction

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mtime_q <= 64'd0;
        end else begin
            mtime_q <= mtime_q + 64'd1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mtimecmp_q <= 64'hFFFF_FFFF_FFFF_FFFF;
            resp_valid_o <= 1'b0;
            resp_rdata_o <= 64'd0;
        end else begin
            if (resp_valid_o && resp_ready_i)
                resp_valid_o <= 1'b0;

            if (req_valid_i && req_ready_o) begin
                resp_valid_o <= 1'b1;
                if (req_we_i) begin
                    case (req_addr_i[3:0])
                        4'h8: mtimecmp_q[31:0] <= apply_wstrb32(
                            mtimecmp_q[31:0], req_wdata_i[31:0], req_wstrb_i[3:0]);
                        4'hC: mtimecmp_q[63:32] <= apply_wstrb32(
                            mtimecmp_q[63:32], req_wdata_i[63:32], req_wstrb_i[7:4]);
                        default: ;
                    endcase
                end else begin
                    case (req_addr_i[3:0])
                        4'h0: resp_rdata_o <= {32'd0, mtime_q[31:0]};
                        4'h4: resp_rdata_o <= {mtime_q[63:32], 32'd0};
                        4'h8: resp_rdata_o <= {32'd0, mtimecmp_q[31:0]};
                        4'hC: resp_rdata_o <= {mtimecmp_q[63:32], 32'd0};
                        default: resp_rdata_o <= 64'd0;
                    endcase
                end
            end
        end
    end

    assign req_ready_o = !resp_valid_o || resp_ready_i;
    assign irq_timer_o = (mtime_q >= mtimecmp_q);

endmodule
