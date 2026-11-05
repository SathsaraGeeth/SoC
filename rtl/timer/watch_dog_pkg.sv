package watch_dog_pkg;

parameter int XLEN        = isa_pkg::XLEN;
parameter int VIR_ADDR_W  = core_pkg::VIR_ADDR_W;
parameter int PRIV_MODE_W = isa_pkg::PRIV_MODE_W;
parameter int THRD_W      = $clog2(core_pkg::NUM_HW_THRDS);

typedef isa_pkg::priv_mode_e priv_mode_e;
localparam priv_mode_e PRIV_MODE_M = isa_pkg::PRIV_MODE_M;

parameter logic [XLEN-1:0] WD_MIN_TIMEOUT = XLEN'(1);
parameter logic [XLEN-1:0] WD_MIN_GRACE   = XLEN'(1);
parameter logic [XLEN-1:0] WD_KICK_KEY    = XLEN'(64'h5744544B49434B31);

typedef struct packed {
    logic en;
    logic irq_en;
    logic rst_en;
} ctrl_t;

function automatic ctrl_t unpack_ctrl (logic [XLEN-1:0] data);
    ctrl_t ctrl;
    ctrl.en      = data[0];
    ctrl.irq_en  = data[1];
    ctrl.rst_en  = data[2];
    return ctrl;
endfunction: unpack_ctrl

typedef struct packed {
    logic en;
    logic irq_pend;
    logic rst_pend;
    logic locked;
    logic bad_kick;
    logic config_err;
    logic key1_pend;
} status_t;

function automatic status_t unpack_status (logic [XLEN-1:0] data);
    status_t status;
    status.en          = data[0];
    status.irq_pend    = data[1];
    status.rst_pend    = data[2];
    status.locked      = data[3];
    status.bad_kick    = data[4];
    status.config_err  = data[5];
    status.key1_pend   = data[6];
    return status;
endfunction: unpack_status

typedef enum logic [3:0] {
    CTRL      = 4'd0,
    TIMEOUT   = 4'd1,
    GRACE     = 4'd2,
    KICK      = 4'd3,
    LOCK      = 4'd4,
    STATUS    = 4'd5,
    COUNT     = 4'd6,
    RST_CAUSE = 4'd7,
    ILLEGAL   = 4'd8
} reg_t;

function automatic reg_t decode_reg (logic [XLEN-1:0] offset);
    unique case (offset)
        64'h00: decode_reg = CTRL;
        64'h08: decode_reg = TIMEOUT;
        64'h10: decode_reg = GRACE;
        64'h18: decode_reg = KICK;
        64'h20: decode_reg = LOCK;
        64'h28: decode_reg = STATUS;
        64'h30: decode_reg = COUNT;
        64'h38: decode_reg = RST_CAUSE;
        default begin
`ifdef SYNTHESIS
    $info("Invalid register offset: %h", offset);
`endif            
                 decode_reg = ILLEGAL;
        end
    endcase
endfunction: decode_reg

endpackage: watch_dog_pkg
