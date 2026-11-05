package mtimer_cmp_pkg;

parameter int XLEN        = isa_pkg::XLEN;
parameter int VIR_ADDR_W  = core_pkg::VIR_ADDR_W;
parameter int PRIV_MODE_W = isa_pkg::PRIV_MODE_W;
parameter int THRD_W      = $clog2(core_pkg::NUM_HW_THRDS);

typedef isa_pkg::priv_mode_e priv_mode_e;
localparam priv_mode_e PRIV_MODE_M = isa_pkg::PRIV_MODE_M;

typedef enum {
    MTIME,
    MTIMECMP,
    ILLEGAL
} reg_t;

function automatic reg_t decode_reg (logic [XLEN-1:0] offset);
    unique case (offset)
        64'h00:  return MTIME;
        64'h08:  return MTIMECMP;
        default begin
`ifdef SYNTHESIS
    $info("Invalid register offset: %h", offset);
`endif
                 return ILLEGAL;
        end
    endcase
endfunction: decode_reg

endpackage: mtimer_cmp_pkg
