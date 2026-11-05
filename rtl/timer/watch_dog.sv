/*
 * watch_dog.sv
 * 
 * Copyright (C) 2026 Sathsara Geeth
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. Should live in a seprate clk domain (always on)
 * 2. kick reg, enable reg, lock reg, timeout reg
 * 3. interrupt out, reset out
 * 4. behavior if hasn't been kicked for timeout period
 *    then first interrupt then after a while reset
 * 5. you have to kick with a key then reverse the key
 *    to successfully kick the dog
 * 6. you can unlock after the a full power reset
 *    since we put the wd in always on reset domain
 * 7. Grace Register - period between irq and rst
 * 8. Memory Map
 *    - M mode: RW access to all registers
 *    - S mode: RO access to all registers, WO access to KICK
 *    - U mode: no access
 *
 *    Offset | Name      | Access      | Description
 *    -------+-----------+-------------+--------------------------------------------
 *    0x00   | CTRL      | RW, Locked  | |                                   |2|1|0|
 *           |           |             | 0-en, 1-irq_en, 2-rst_en
 *    -------+-----------+-------------+--------------------------------------------
 *    0x08   | TIMEOUT   | RW, Locked  | |           IRQ TIMEOUT TICKS             |
 *    -------+-----------+-------------+--------------------------------------------
 *    0x10   | GRACE     | RW, Locked  | |           GRACE PERIOD TICKS            |
 *    -------+-----------+-------------+--------------------------------------------
 *    0x18   | KICK      | WO          | |             KICK KEY VALUE              |
 *    -------+-----------+-------------+--------------------------------------------
 *    0x20   | LOCK      | RW1S        | |                                       |0|
 *           |           |             | 0-lock
 *    -------+-----------+-------------+--------------------------------------------
 *    0x28   | STATUS    | RO/W1C      | |                                |4|3|2|1|0|
 *           |           |             | 0-en(ro),1-irq_pend(row1c),2-rst_pend(ro),
 *           |           |             | 3-locked(ro),4-bad_kick(w1c),
 *           |           |             | 5-config_err(w1c), 5-key1_pend(ro) 
 *    -------+-----------+-------------+--------------------------------------------
 *    0x30   | COUNT     | RO          | |         CURRENT WATCHDOG COUNT          |
 *    -------+-----------+-------------+--------------------------------------------
 *    0x38   | RST_CAUSE | RO/W1C      | |                                       |0|
 *           |           |             | 0-wd_reset
 *    -------+-----------+-------------+--------------------------------------------
 * 9. The dog do the watching only after it is locked
 */


`timescale 1ps/1ps
`default_nettype none

import  watch_dog_pkg::*;

module watch_dog #(
    parameter BASE_ADDR = 64'h0
)(
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic                            i_req_we,
    input  logic [THRD_W-1:0]               i_req_thrd,
    input  logic                            i_req_is_lr,
    input  logic                            i_req_is_sc,
    input  logic [VIR_ADDR_W-1:0]           i_req_addr,
    input  logic [XLEN/8-1:0]               i_req_wstrb,
    input  logic [XLEN-1:0]                 i_req_wdata,
    input  logic                            i_req_valid,
    input  logic [PRIV_MODE_W-1:0]          i_req_priv,
    output logic                            o_req_ready,
    output logic [THRD_W-1:0]               o_resp_thrd,
    output logic                            o_resp_sc_succ,
    output logic [XLEN-1:0]                 o_resp_rdata,
    output logic                            o_resp_valid,
    input  logic                            i_resp_ready,
    output logic                            o_irq,
    output logic                            o_rst
);
    /* MMIO regs---  */
    logic            r_en;
    logic            r_irq_en;
    logic            r_rst_en;
    logic [XLEN-1:0] r_timeout;
    logic [XLEN-1:0] r_grace;
    logic            r_lock;
    logic [XLEN-1:0] r_wdctr;
    logic            r_irq_pend;
    logic            r_rst_pend;
    logic            r_bad_kick;
    logic            r_config_err;
    logic            r_key1_pend;
    logic            r_wd_reset;
    /*  ---MMIO regs */

    /* register the request---  */
    watch_dog_pkg::reg_t    r_req_type;
    logic                   r_req_we;
    logic [XLEN-1:0]        r_req_wdata;
    logic [XLEN/8-1:0]      r_req_wstrb;
    priv_mode_e             r_req_priv;
    logic                   r_req_valid;
    logic [THRD_W-1:0]      r_req_thrd;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_req_type   <= watch_dog_pkg::ILLEGAL;
            r_req_we     <= '0;
            r_req_wdata  <= '0;
            r_req_wstrb  <= '0;
            r_req_priv   <= PRIV_MODE_M;
            r_req_valid  <= '0;
            r_req_thrd   <= '0;
        end else begin
            if (i_req_valid && o_req_ready) begin
                r_req_type   <= watch_dog_pkg::decode_reg(i_req_addr-BASE_ADDR);
                r_req_we     <= i_req_we;
                r_req_wdata  <= i_req_wdata;
                r_req_wstrb  <= i_req_wstrb;
                r_req_priv   <= priv_mode_e'(i_req_priv);
                r_req_valid  <= 1'b1;
                r_req_thrd   <= i_req_thrd;
            end else begin
                r_req_valid  <= 1'b0;
            end
        end
    end
    /* ---register the request */

    /* MMIO writes---  */
    always_ff @(posedge i_clk) begin: ctrl
        if (!i_rst_n) begin
            r_en         <= 1'b0;
            r_irq_en     <= 1'b0;
            r_rst_en     <= 1'b0;
            r_config_err <= 1'b0;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == CTRL)) begin
            if (r_req_we) begin
                if (!r_lock) begin
                    {r_en, r_irq_en, r_rst_en} <= unpack_ctrl(r_req_wdata);
                end else begin
                    r_config_err <= 1'b1;
                end
            end
        end
    end: ctrl

    always_ff @(posedge i_clk) begin: lock
        if (!i_rst_n) begin
            r_lock       <= 1'b0;
            r_config_err <= 1'b0;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == LOCK)) begin
            r_lock <= r_req_wdata[0];
`ifdef VERILATOR
            $display("[WD RTL] LOCK write data=%h timeout=%0d grace=%0d",
                     r_req_wdata, r_timeout, r_grace);
`endif
            if (r_grace < WD_MIN_GRACE) begin
                r_config_err <= 1'b1;
            end 
            if (r_timeout < WD_MIN_TIMEOUT) begin
                r_config_err <= 1'b1;
            end
        end
    end: lock

    always_ff @(posedge i_clk) begin: timeout
        if (!i_rst_n) begin
            r_timeout    <= WD_MIN_TIMEOUT;
            r_config_err <= 1'b0;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == TIMEOUT)) begin
            if (!r_lock) begin
                r_timeout <= r_req_wdata;
`ifdef VERILATOR
                $display("[WD RTL] TIMEOUT write=%0d (%h)", r_req_wdata, r_req_wdata);
`endif
            end else begin
                r_config_err <= 1'b1;
            end
        end
    end: timeout
    
    always_ff @(posedge i_clk) begin: grace
        if (!i_rst_n) begin
            r_grace <= WD_MIN_GRACE;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == GRACE)) begin
            if (!r_lock) begin
                r_grace <= r_req_wdata;
`ifdef VERILATOR
                $display("[WD RTL] GRACE write=%0d (%h)", r_req_wdata, r_req_wdata);
`endif
            end else begin
                r_config_err <= 1'b1;
            end
        end
    end: grace

    always_ff @(posedge i_clk) begin: status_w1c
        if (!i_rst_n) begin
            r_irq_pend    <= 1'b0;
            r_rst_pend    <= 1'b0;
            r_bad_kick    <= 1'b0;
            r_config_err  <= 1'b0;
            r_key1_pend   <= 1'b0;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == STATUS)) begin
            automatic status_t status = unpack_status(r_req_wdata);
            if (status.irq_pend) begin
                r_irq_pend <= 1'b0;
            end
            if (status.bad_kick) begin
                r_bad_kick <= 1'b0;
            end
            if (status.config_err) begin
                r_config_err <= 1'b0;
            end
            if (status.key1_pend) begin
                r_key1_pend <= 1'b0;
            end
        end
        r_rst_pend <= w_dog_reset;
        if (i_rst_n && w_dog_intr) begin
            r_irq_pend <= 1'b1;
`ifdef VERILATOR
            $display("[WD RTL] TIMEOUT reached count=%0d timeout=%0d", r_wdctr, r_timeout);
`endif
        end
    end: status_w1c

    always_ff @(posedge i_clk) begin: rst_cause_w1c
        if (!i_rst_n) begin
            r_wd_reset <= 1'b0;
        end else if (w_dog_reset) begin
            r_wd_reset <= 1'b1;
        end else if (r_req_we && (r_req_priv == PRIV_MODE_M) && r_req_valid && (r_req_type == RST_CAUSE)) begin
            if (r_req_wdata[0]) begin
                r_wd_reset <= 1'b0;
            end
        end
    end: rst_cause_w1c
    /*  ---MMIO writes */

    /* MMIO reads---  */
    logic   r_read_busy;
    always_ff @(posedge i_clk) begin: mmio_reads
        if (!i_rst_n) begin
            r_read_busy  <= 1'b0;
            o_resp_thrd  <= '0;
            o_resp_rdata <= '0;
            o_resp_valid <= 1'b0;
        end else if (r_req_valid) begin
            r_read_busy <= 1'b1;
            unique case (r_req_type)
                CTRL:       o_resp_rdata <= {61'b0, r_rst_en, r_irq_en, r_en};
                TIMEOUT:    o_resp_rdata <= r_timeout;
                GRACE:      o_resp_rdata <= r_grace;
                KICK:       o_resp_rdata <= '0;
                LOCK:       o_resp_rdata <= {63'b0, r_lock};
                STATUS:     o_resp_rdata <= {57'b0, r_key1_pend, r_config_err, r_bad_kick, r_lock, r_rst_pend, r_irq_pend, r_en};
                COUNT:      o_resp_rdata <= r_wdctr;
                RST_CAUSE:  o_resp_rdata <= {63'b0, r_wd_reset};
                default begin    
                            o_resp_rdata <= '0;
            `ifdef SYNTHESIS
                $info("Invalid register type: %d", r_req_type);
            `endif          
                        end
            endcase
            o_resp_valid <= 1'b1;
        end else if (o_resp_valid && i_resp_ready) begin
            r_read_busy  <= 1'b0;
            o_resp_valid <= 1'b0;
        end
        o_resp_thrd    <= r_req_thrd;
        o_resp_sc_succ <= 1'b0;
    end: mmio_reads

    assign o_req_ready = !r_read_busy && !r_req_valid;
    /* ---MMIO reads */

    /* irq && rst output---  */
    assign o_irq = r_irq_pend && r_irq_en;
    assign o_rst = r_rst_pend && r_rst_en;
    /*  ---irq && rst output */

    /* ctr---  */
    always_ff @(posedge i_clk) begin: wd_ctr
        if (!i_rst_n) begin
            r_wdctr <= '0;
        end else if (w_dog_reset) begin
            r_wdctr <= '0;
        end else if (r_en && !r_lock) begin
            r_wdctr <= '0;
        end else if (r_en && r_lock) begin
            if (r_req_valid && r_req_type == KICK && s_dog_this == DOG_KICKED && r_req_wdata == ~WD_KICK_KEY) begin
                r_wdctr <= '0;
            end else if (r_wdctr < (r_timeout + r_grace)) begin
                r_wdctr <= r_wdctr + 1'b1;
            end
        end else begin
            r_wdctr <= '0;
        end
    end: wd_ctr
    /*  ---ctr */

    /*  dog---  */
    logic w_dog_reset;
    logic w_dog_intr;

    typedef enum {
        DOG_SLEEP,
        DOG_KICKED,
        DOG_AWAKE
    } dog_state_t;

    dog_state_t s_dog_this, s_dog_next;

    always_ff @(posedge i_clk) begin: dog_fsm
        if (!i_rst_n) begin
            s_dog_this <= DOG_SLEEP;
        end else begin
            s_dog_this <= s_dog_next;
        end
    end: dog_fsm

    always_comb begin: dog_fsm_next
        s_dog_next = s_dog_this;
        case (s_dog_this)
            DOG_SLEEP: begin
                if (r_en && r_lock && r_req_type == KICK && r_req_wdata == WD_KICK_KEY) begin
                    s_dog_next = DOG_KICKED;
                end else if (r_en && r_lock && r_wdctr >= r_timeout) begin
                    s_dog_next = DOG_AWAKE;
                end
            end
            DOG_KICKED: begin
                if (r_en && r_lock && r_req_type == KICK && r_req_wdata == ~WD_KICK_KEY) begin
                    s_dog_next = DOG_SLEEP;
                end
            end
            DOG_AWAKE: begin
                if (r_wdctr >= (r_timeout + r_grace)) begin
                    s_dog_next = DOG_SLEEP;
                end
            end
            default: begin
                s_dog_next = DOG_SLEEP;
            end
        endcase
    end: dog_fsm_next

    always_comb begin
        w_dog_intr  = 1'b0;
        w_dog_reset = 1'b0;
        if ((s_dog_this == DOG_SLEEP) && r_wdctr >= r_timeout) begin
            w_dog_intr = 1'b1;
        end
        if ((s_dog_this == DOG_AWAKE) && r_wdctr >= (r_timeout + r_grace)) begin
            w_dog_reset = 1'b1;
        end
    end
    /*  ---dog */
endmodule: watch_dog

`default_nettype wire
