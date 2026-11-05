`default_nettype none

import core_pkg::*;

module csr_formal (
    input logic                            clk,
    input logic                            rst_n,
    input logic                            we,
    input logic [XLEN-1:0]                 thread_id_vec [NUM_HW_THRDS-1:0],
    input logic [NUM_HW_THRDS-1:0]         irq_timer_vec,
    input logic [$clog2(CSR_COUNT)-1:0]    rs1_addr_vec [NUM_HW_THRDS-1:0],
    input logic [$clog2(CSR_COUNT)-1:0]    rd_addr,
    input logic [$clog2(NUM_HW_THRDS)-1:0] wthrd_id,
    input logic [XLEN-1:0]                 rd_wdata,
    input logic                            trap_we,
    input logic [XLEN-1:0]                 trap_mepc,
    input logic [XLEN-1:0]                 trap_mcause,
    input logic [XLEN-1:0]                 trap_tval,
    input logic                            trap_to_s,
    input logic                            mret_we,
    input logic                            sret_we
);
    logic [NUM_HW_THRDS-1:0]         irq_pending_vec;
    logic [XLEN-1:0]                 rs1_data_vec [NUM_HW_THRDS-1:0];
    logic [isa_pkg::PRIV_MODE_W-1:0] priv_mode_vec [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                 medeleg_vec [NUM_HW_THRDS-1:0];
    logic [XLEN-1:0]                 mideleg_vec [NUM_HW_THRDS-1:0];
    logic                            f_past_valid = 1'b0;

    csr dut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .i_we            (we),
        .i_thread_id_vec (thread_id_vec),
        .i_irq_timer_vec (irq_timer_vec),
        .o_irq_pending_vec(irq_pending_vec),
        .i_rs1_addr_vec  (rs1_addr_vec),
        .o_rs1_data_vec  (rs1_data_vec),
        .i_rd_addr       (rd_addr),
        .i_wthrd_id      (wthrd_id),
        .i_rd_wdata      (rd_wdata),
        .i_trap_we       (trap_we),
        .i_trap_mepc     (trap_mepc),
        .i_trap_mcause   (trap_mcause),
        .i_trap_tval     (trap_tval),
        .i_trap_to_s     (trap_to_s),
        .i_mret_we       (mret_we),
        .i_sret_we       (sret_we),
        .o_priv_mode_vec (priv_mode_vec),
        .o_medeleg_vec   (medeleg_vec),
        .o_mideleg_vec   (mideleg_vec)
    );

    always_ff @(posedge clk)
        f_past_valid <= 1'b1;

    `include "csr_assumptions.sv"
    `include "csr_reset.sv"
    `include "csr_reads.sv"
    `include "csr_privilege.sv"
    `include "csr_coverpoints.sv"
endmodule: csr_formal

`default_nettype wire

