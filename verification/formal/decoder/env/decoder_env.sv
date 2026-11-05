`default_nettype none

import core_pkg::*;

module decoder_formal (
    input logic                     clk,
    input logic [isa_pkg::INST_W-1:0] instr
);
    decoded_instr_t decoded;

    decoder dut (
        .i_instr   (instr),
        .o_decoded (decoded)
    );

    `include "decoder_invariants.sv"
    `include "decoder_routes.sv"
    `include "decoder_coverpoints.sv"
endmodule: decoder_formal

`default_nettype wire

