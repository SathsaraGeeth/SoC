/*
 * sys_core.sv
 *
 * Copyright (C) 2026 Sathsara Geeth
 */

/*
 * Comments:
 * 1. Command structure:
 *      I.   typeI:     [start_blk/last_blk/start_last_blk/dense_flag/mac_type][A_size,B_size(if only dense, this is the element size)][addrA][addrB]
 *      II.  typeII:    [write_back(is_dense)/mac_type][addrD]
 *      III. typeIII:   [delegation][tid][vtid]
 *      IV.  typeIV:    [release_responsibility][vtid]
 *
 * encodings:
 *      I.   typeI:    | 8b typeID, 2b start/last, 1b dense, 2b mac_type, pad to 32b | 16b size A, 16b size B | addr A | addr B |
 *      II.  typeII:   | 8b typeID, 1b dense, 2b mac_type, pad to 32b                | addr D                | pad    | pad    |
 *      III. typeIII:  | 8b typeID,      (pad to 32bits) | 32b vtid                  | 32btid       | pad32b       |
 *      IV.  typeIV:   | 8b typeID,      (pad to 32bits) | 32b vtid                  | pad32b       | pad32b       |
 *
 * 2. If the mmio ready the host can write commands to the buffer
 *    The commands must start with a type III command. Then the sysarray
 *    use those identities to communicate with the memory system.
 *    The array blocks the mmio interface to any other thread ids right after type III
 *    command is accepted.
 *
 *    Then after that event, there will be a sequence of typeII and typeI
 *    commands. The array can start executing them immediately and independently,
 *    in order. Unlike the type III command they get enqueued to the command
 *    buffer and drained decoupledly.
 *
 *    The command buffer head drives the systolic array directly.
 *
 *    In type I commands start means the start of a block and last means the
 *    last block. break is an internal signal and is not equal to last.
 *
 *    Type I triggers memory reads and type II triggers memory writes.
 *    Do not assume one typeII per one typeI; start/last allow chaining.
 *
 * 2A. if dense type I must comes from typeI, even if native type I (one or a seq) comes first.
 *
 * 3. Then a typeIV command arrives at the end of the sequence. It is also
 *    enqueued to the command buffer. When the buffer head reaches typeIV, it
 *    releases the mmio interface.
 *
 * 4. This facilitates virtual memory compliance and lets the systolic array
 *    start right after the first command, without waiting for the entire set.
 *
 * 5. So we have a command buffer fifo above tasks.
 *
 * 6. the mmacu_core_v2 is used to implement this.
 */

`timescale 1ns/1ps
`default_nettype none

import sys_cnfg_pkg::*;
import isa_pkg::*;
import core_pkg::*;
import topology_pkg::*;
import memory_pkg::*;

module sys_core #(
    parameter int M = 8,
    parameter int K = 8,
    parameter int WIDTH_AB = 8,
    parameter int WIDTH_CD = sys_cnfg_pkg::WIDTH_CD
) (
    input  logic                               i_clk,
    input  logic                               i_rst_n,

    input  logic                               i_mmio_req_valid,
    input  logic [VIR_ADDR_W-1:0]              i_mmio_req_addr,
    input  logic [XLEN-1:0]                    i_mmio_req_wdata,
    input  logic [XLEN/8-1:0]                  i_mmio_req_wmask,
    output logic                               o_mmio_req_ready,
    output logic                               o_mmio_resp_valid,
    output logic [XLEN-1:0]                    o_mmio_resp_rdata,
    input  logic                               i_mmio_resp_ready,
    input  logic [THRD_W-1:0]                  i_host_thrd,
    output logic                               o_intr,
    output logic [XLEN-1:0]                    o_intr_thrd,

    output logic                               o_req_we        [NUM_PORTS-1:0],
    output logic [XLEN-1:0]                    o_req_thrd      [NUM_PORTS-1:0],
    output logic                               o_req_is_lr     [NUM_PORTS-1:0],
    output logic                               o_req_is_sc     [NUM_PORTS-1:0],
    output logic [VIR_ADDR_W-1:0]              o_req_addr      [NUM_PORTS-1:0],
    output logic [XLEN/8-1:0]                  o_req_wstrb     [NUM_PORTS-1:0],
    output logic [XLEN-1:0]                    o_req_wdata     [NUM_PORTS-1:0],
    output logic                               o_req_valid     [NUM_PORTS-1:0],
    input  logic                               i_req_ready     [NUM_PORTS-1:0],
    input  logic [XLEN-1:0]                    i_resp_thrd     [NUM_PORTS-1:0],
    input  logic                               i_resp_sc_succ  [NUM_PORTS-1:0],
    input  logic [XLEN-1:0]                    i_resp_rdata    [NUM_PORTS-1:0],
    input  logic                               i_resp_valid    [NUM_PORTS-1:0],
    output logic                               o_resp_ready    [NUM_PORTS-1:0]
);

    /* Commands capturing---  */
    logic [XLEN-1:0]                r_owner_thrd;
    logic                           r_owned;
    logic [CMD_W-1:0]               r_cmd;
    logic [$clog2(CMD_W/XLEN)-1:0]  r_cmd_word_cnt;
    logic                           r_mmio_resp_valid;

    logic                           w_r_cmd_valid;
    logic                           w_cmd_enq_valid;
    logic                           w_cmd_enq_ready;
    logic                           w_cmd_deq_valid;
    logic                           w_cmd_deq_ready;
    logic [CMD_W+XLEN-1:0]          w_cmd_head_data;
    logic [CMD_W-1:0]               w_cmd_tail_data;
    logic                           r_wb_valid;
    logic [CMD_W-1:0]               r_wb_cmd;
    logic [XLEN-1:0]                r_wb_tid;

    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_cmd          <= '0;
            r_cmd_word_cnt <= '0;
        end else if (o_mmio_req_ready && i_mmio_req_valid && (i_mmio_req_wmask != '0) && (i_mmio_req_addr[7:0] == 8'h08)) begin
            r_cmd          <= {i_mmio_req_wdata, r_cmd[CMD_W-1:XLEN]};
            r_cmd_word_cnt <= r_cmd_word_cnt + 1'b1;
            if (r_cmd_word_cnt == $clog2(CMD_W/XLEN)'(CMD_W/XLEN-1)) begin
                r_cmd_word_cnt <= '0;
            end
        end
    end

    logic                            r_cmd_done;
    logic [XLEN-1:0]                 r_mmio_resp_rdata;
    logic [$clog2(CMD_BUFF_D+1)-1:0] w_cmd_level;
    logic                            w_busy;
    logic                            r_busy;
    logic [XLEN-1:0]                 r_accel_cycles;
    logic [XLEN-1:0]                 r_last_accel_cycles;
    logic [XLEN-1:0]                 r_intr_thrd;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_cmd_done <= 1'b0;
        end else begin
            r_cmd_done <= o_mmio_req_ready && i_mmio_req_valid &&
                          (i_mmio_req_wmask != '0) && (i_mmio_req_addr[7:0] == 8'h08) &&
                          (r_cmd_word_cnt == $clog2(CMD_W/XLEN)'(CMD_W/XLEN-1));
        end
    end

    assign o_mmio_req_ready  = !r_mmio_resp_valid &&
                               (!r_owned || ((XLEN'(i_host_thrd) == r_owner_thrd) &&
                                             w_cmd_enq_ready && !r_wb_valid));
    assign o_mmio_resp_valid = r_mmio_resp_valid;
    assign o_mmio_resp_rdata = r_mmio_resp_rdata;
    assign w_r_cmd_valid     = r_cmd_done;
    assign w_cmd_tail_data   = r_cmd;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_mmio_resp_valid <= 1'b0;
            r_mmio_resp_rdata <= '0;
        end else if (i_mmio_req_valid && o_mmio_req_ready) begin
            r_mmio_resp_valid <= 1'b1;
            case (i_mmio_req_addr[7:0])
                8'h00: r_mmio_resp_rdata   <= XLEN'(w_busy << 3);
                8'h10: r_mmio_resp_rdata   <= r_last_accel_cycles;
                default: r_mmio_resp_rdata <= '0;
            endcase
        end else if (r_mmio_resp_valid && i_mmio_resp_ready) begin
            r_mmio_resp_valid <= 1'b0;
        end
    end

    assign w_busy = r_owned || r_wb_valid || (w_cmd_level != '0) || (w_addrA_level != '0) || (w_addrB_level != '0) ||
                    (w_addrD_level != '0) || (w_out_level != '0) || w_drvA_deq_ready || w_drvB_deq_ready || w_d_valid;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_busy              <= 1'b0;
            r_accel_cycles      <= '0;
            r_last_accel_cycles <= '0;
            o_intr              <= 1'b0;
            r_intr_thrd         <= '0;
        end else begin
            o_intr <= r_busy && !w_busy;
            if (!r_busy && w_busy) begin
                r_accel_cycles <= XLEN'(1);
            end else if (w_busy) begin
                r_accel_cycles <= r_accel_cycles + XLEN'(1);
            end
            if (r_busy && !w_busy) begin
                r_last_accel_cycles <= r_accel_cycles;
            end
            if (w_r_cmd_valid && is_cmd_delegation(r_cmd)) begin
                r_intr_thrd <= get_cmd_tid(r_cmd);
            end
            r_busy <= w_busy;
        end
    end
    assign o_intr_thrd = r_intr_thrd;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_owner_thrd    <= '0;
            r_owned         <= 1'b0;
            r_wb_valid      <= 1'b0;
            r_wb_cmd        <= '0;
            r_wb_tid        <= '0;
            w_cmd_enq_valid <= 1'b0;
        end else begin
            w_cmd_enq_valid <= 1'b0;
            if (w_done_d)
                r_wb_valid <= 1'b0;
            if (w_r_cmd_valid) begin
                if (is_cmd_delegation(r_cmd)) begin
                    r_owner_thrd <= get_cmd_tid(r_cmd);
                    r_owned      <= 1'b1;
                end
                else if (is_cmd_release(r_cmd)) begin
                    r_owned <= 1'b0;
                end
                else if (is_cmd_op(r_cmd)) begin
                    w_cmd_enq_valid <= 1'b1;
                end
                else if (is_cmd_wb(r_cmd)) begin
                    r_wb_valid <= 1'b1;
                    r_wb_cmd   <= r_cmd;
                    r_wb_tid   <= r_owner_thrd;
                end
            end
        end
    end

    circular_buffer #(.WIDTH(CMD_W+XLEN), .DEPTH(CMD_BUFF_D)) cmd_buff (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_enq_valid        (w_cmd_enq_valid), 
        .i_enq_tail_data    ({w_cmd_tail_data, r_owner_thrd}), 
        .o_enq_ready        (w_cmd_enq_ready),
        .i_deq_valid        (w_cmd_deq_valid), 
        .o_deq_ready        (w_cmd_deq_ready), 
        .o_head_data        (w_cmd_head_data),
        .o_full             (),
        .o_empty            (),
        .o_level            (w_cmd_level),
        .i_clr_n            (1'b1)
    );
    /*  ---Commands capturing */




    /* Address generation and address FIFOs--- */
    logic [CMD_W-1:0]                              w_head_cmd;
    logic [XLEN-1:0]                               w_head_tid;
    logic                                          w_head_is_op;
    logic                                          w_head_is_wb;
    logic                                          w_head_is_dense;
    logic                                          w_head_is_dense_wb;
    logic [TILE_W-1:0]                             w_op_a_tiles;
    logic [TILE_W-1:0]                             w_op_b_tiles;
    logic [TILE_W-1:0]                             w_wb_a_tiles;
    logic [TILE_W-1:0]                             w_wb_b_tiles;
    logic [TILE_W-1:0]                             r_last_a_tiles;
    logic [TILE_W-1:0]                             r_last_b_tiles;
    logic                                          r_lag_started_a;
    logic                                          r_lag_started_b;
    logic                                          r_lag_started_d;

    logic                                          w_addrA_enq_valid;
    logic                                          w_addrA_enq_ready;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_addrA_enq_data;
    logic                                          w_addrA_deq_valid;
    logic                                          w_addrA_deq_ready;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_addrA_head_data;
    logic                                          w_addrB_enq_valid;
    logic                                          w_addrB_enq_ready;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_addrB_enq_data;
    logic                                          w_addrB_deq_valid;
    logic                                          w_addrB_deq_ready;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_addrB_head_data;
    logic                                          w_addrD_enq_valid;
    logic                                          w_addrD_enq_ready;
    logic [VIR_ADDR_W+XLEN-1:0]                    w_addrD_enq_data;
    logic                                          w_addrD_deq_valid;
    logic                                          w_addrD_deq_ready;
    logic [VIR_ADDR_W+XLEN-1:0]                    w_addrD_head_data;
    logic                                          w_done_a;
    logic                                          w_done_b;
    logic                                          w_done_d;
    logic                                          w_lag_done_a;
    logic                                          w_lag_done_b;
    logic                                          r_lag_done_a_seen;
    logic                                          r_lag_done_b_seen;
    logic [VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_addrD_enq_data_full;
    
    assign w_head_cmd         = w_cmd_head_data[CMD_W+XLEN-1:XLEN];
    assign w_head_tid         = w_cmd_head_data[XLEN-1:0];
    assign w_head_is_op       = w_cmd_deq_ready && is_cmd_op(w_head_cmd);
    assign w_head_is_wb       = r_wb_valid;
    assign w_head_is_dense    = is_cmd_dense(w_head_cmd);
    assign w_head_is_dense_wb = is_cmd_dense_wb(r_wb_cmd);
    assign w_op_a_tiles       = is_cmd_dense(w_head_cmd) ? TILE_W'(get_cmd_a_size(w_head_cmd)) : TILE_W'(DEFAULT_TILES);
    assign w_op_b_tiles       = is_cmd_dense(w_head_cmd) ? TILE_W'(get_cmd_b_size(w_head_cmd)) : TILE_W'(DEFAULT_TILES);
    assign w_wb_a_tiles       = w_head_is_dense_wb ? r_last_a_tiles : TILE_W'(DEFAULT_TILES);
    assign w_wb_b_tiles       = w_head_is_dense_wb ? r_last_b_tiles : TILE_W'(DEFAULT_TILES);
    assign w_addrD_enq_data   = w_addrD_enq_data_full[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W-1:MAC_W+ADDR_FLAGS_W];
    assign w_cmd_deq_valid    = w_cmd_deq_ready && ((is_cmd_op(w_head_cmd) && w_done_a && w_done_b) ||
                               is_cmd_delegation(w_head_cmd) || is_cmd_release(w_head_cmd));

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_last_a_tiles <= TILE_W'(DEFAULT_TILES);
            r_last_b_tiles <= TILE_W'(DEFAULT_TILES);
        end else if (w_head_is_op && is_cmd_dense(w_head_cmd)) begin
            r_last_a_tiles <= TILE_W'(get_cmd_a_size(w_head_cmd));
            r_last_b_tiles <= TILE_W'(get_cmd_b_size(w_head_cmd));
        end
    end
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_lag_started_a   <= 1'b0;
            r_lag_started_b   <= 1'b0;
            r_lag_started_d   <= 1'b0;
            r_lag_done_a_seen <= 1'b0;
            r_lag_done_b_seen <= 1'b0;
        end else begin
            if (w_head_is_op && !r_lag_started_a) begin
                r_lag_started_a <= 1'b1;
            end
            if (w_head_is_op && !r_lag_started_b) begin
                r_lag_started_b <= 1'b1;
            end
            if (r_wb_valid && !r_lag_started_d) begin
                r_lag_started_d <= 1'b1;
            end
            if (w_lag_done_a) begin
                r_lag_done_a_seen <= 1'b1;
            end
            if (w_lag_done_b) begin
                r_lag_done_b_seen <= 1'b1;
            end
            if (w_cmd_deq_valid && w_cmd_deq_ready) begin
                r_lag_started_a   <= 1'b0;
                r_lag_started_b   <= 1'b0;
                r_lag_done_a_seen <= 1'b0;
                r_lag_done_b_seen <= 1'b0;
            end
            if (w_done_d) begin
                r_lag_started_d <= 1'b0;
            end
        end
    end

    sys_address_generator #(.IS_WB(1'b0), .IS_B(1'b0)) u_lag_a (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_start            (w_head_is_op && !r_lag_started_a),
        .i_tid              (w_head_tid),
        .i_base_addr        (get_cmd_a_addr(w_head_cmd)),
        .i_a_tiles          (w_op_a_tiles),
        .i_b_tiles          (w_op_b_tiles),
        .i_dense            (w_head_is_dense),
        .i_cmd_start        (is_cmd_start(w_head_cmd)),
        .i_cmd_last         (is_cmd_last(w_head_cmd)),
        .i_mac_type         (get_cmd_mac_type(w_head_cmd)),
        .i_addr_enq_ready   (w_addrA_enq_ready),
        .o_addr_enq_valid   (w_addrA_enq_valid),
        .o_addr_enq_data    (w_addrA_enq_data),
        .o_done             (w_lag_done_a)
    );

    sys_address_generator #(.IS_WB(1'b0), .IS_B(1'b1)) u_lag_b (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_start            (w_head_is_op && !r_lag_started_b),
        .i_tid              (w_head_tid),
        .i_base_addr        (get_cmd_b_addr(w_head_cmd)),
        .i_a_tiles          (w_op_a_tiles),
        .i_b_tiles          (w_op_b_tiles),
        .i_dense            (w_head_is_dense),
        .i_cmd_start        (is_cmd_start(w_head_cmd)),
        .i_cmd_last         (is_cmd_last(w_head_cmd)),
        .i_mac_type         (get_cmd_mac_type(w_head_cmd)),
        .i_addr_enq_ready   (w_addrB_enq_ready),
        .o_addr_enq_valid   (w_addrB_enq_valid),
        .o_addr_enq_data    (w_addrB_enq_data),
        .o_done             (w_lag_done_b)
    );

    sys_address_generator #(.IS_WB(1'b1), .IS_B(1'b0)) u_lag_d (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_start            (r_wb_valid && !r_lag_started_d),
        .i_tid              (r_wb_tid),
        .i_base_addr        (get_cmd_d_addr(r_wb_cmd)),
        .i_a_tiles          (w_wb_a_tiles),
        .i_b_tiles          (w_wb_b_tiles),
        .i_dense            (w_head_is_dense_wb),
        .i_cmd_start        (1'b0),
        .i_cmd_last         (1'b0),
        .i_mac_type         (get_cmd_mac_type(r_wb_cmd)),
        .i_addr_enq_ready   (w_addrD_enq_ready),
        .o_addr_enq_valid   (w_addrD_enq_valid),
        .o_addr_enq_data    (w_addrD_enq_data_full),
        .o_done             (w_done_d)
    );

    /*
     * A and B store {vector address, thread id, flags}; D stores
     * {vector address, thread id}. All three queues are vector-granular
     */
    circular_buffer #(.WIDTH(VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+2), .DEPTH(A_ADDR_BUFF)) addrA_buff (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_enq_valid        (w_addrA_enq_valid), 
        .i_enq_tail_data    (w_addrA_enq_data), 
        .o_enq_ready        (w_addrA_enq_ready),
        .i_deq_valid        (w_addrA_deq_valid), 
        .o_deq_ready        (w_addrA_deq_ready), 
        .o_head_data        (w_addrA_head_data), 
        .o_full             (),
        .o_empty            (),
        .o_level            (w_addrA_level),
        .i_clr_n            (1'b1)
    );
    circular_buffer #(.WIDTH(VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+2), .DEPTH(B_ADDR_BUFF)) addrB_buff (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_enq_valid        (w_addrB_enq_valid), 
        .i_enq_tail_data    (w_addrB_enq_data), 
        .o_enq_ready        (w_addrB_enq_ready),
        .i_deq_valid        (w_addrB_deq_valid), 
        .o_deq_ready        (w_addrB_deq_ready), 
        .o_head_data        (w_addrB_head_data), 
        .o_full             (),
        .o_empty            (),
        .o_level            (w_addrB_level),
        .i_clr_n            (1'b1)
    );
    circular_buffer #(.WIDTH(VIR_ADDR_W+XLEN), .DEPTH(D_ADDR_BUFF)) addrD_buff (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_enq_valid        (w_addrD_enq_valid), 
        .i_enq_tail_data    (w_addrD_enq_data), 
        .o_enq_ready        (w_addrD_enq_ready),
        .i_deq_valid        (w_addrD_deq_valid), 
        .o_deq_ready        (w_addrD_deq_ready), 
        .o_head_data        (w_addrD_head_data), 
        .o_full             (),
        .o_empty            (),
        .o_level            (w_addrD_level),
        .i_clr_n            (1'b1)
    );

    /*  ----Address generation and address FIFOs */



    /* Memory Driver--- */
    logic [$clog2(A_ADDR_BUFF+1)-1:0]                    w_addrA_level;
    logic [$clog2(B_ADDR_BUFF+1)-1:0]                    w_addrB_level;
    logic [$clog2(D_ADDR_BUFF+1)-1:0]                    w_addrD_level;
    logic [$clog2(RES_BUFF_D+1)-1:0]                     w_out_level;
    logic [$clog2(OP_BUFF_D+1)-1:0]                      w_drvA_level;
    logic [$clog2(OP_BUFF_D+1)-1:0]                      w_drvB_level;
    logic [$clog2(32+1)-1:0]                             w_req_level [1:0];
    logic                                                w_out_enq_valid;
    logic                                                w_out_enq_ready;
    logic [VEC_W-1:0]                                    w_out_enq_data;
    logic                                                w_out_deq_valid;
    logic                                                w_out_deq_ready;
    logic [VEC_W-1:0]                                    w_out_head_data;
    logic                                                w_drvB_enq_valid;
    logic                                                w_drvB_enq_ready;
    logic [VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_drvB_enq_data;
    logic                                                w_drvB_deq_valid;
    logic                                                w_drvB_deq_ready;
    logic [VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_drvB_head_data;
    logic                                                w_drvA_enq_valid;
    logic                                                w_drvA_enq_ready;
    logic [VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_drvA_enq_data;
    logic                                                w_drvA_deq_valid;
    logic                                                w_drvA_deq_ready;
    logic [VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1:0] w_drvA_head_data;
    logic                                                w_addrA_reused;
    logic                                                w_addrB_reused;
    logic                                                w_drvA_reused;
    logic                                                w_drvB_reused;
    logic                                                w_addrA_dense;
    logic                                                w_addrB_dense;
    logic                                                w_core_dense;

    typedef struct packed {
        logic [XLEN-1:0]         tid;
        logic                    dense;
        mac_t                    mac_type;
        logic [ADDR_FLAGS_W-1:0] flags;
        logic [VIR_ADDR_W-1:0]   addr;
    } read_meta_t;

    logic                                                w_req_fifo_enq_valid [1:0];
    logic                                                w_req_fifo_enq_ready [1:0];
    read_meta_t                                          w_req_fifo_enq_data  [1:0];
    logic                                                w_req_fifo_deq_valid [1:0];
    logic                                                w_req_fifo_deq_ready [1:0];
    read_meta_t                                          w_req_fifo_head_data [1:0];
    logic [VIR_ADDR_W-1:0]                               w_addrA_val_addr;
    logic [XLEN-1:0]                                     w_addrA_val_tid;
    logic [ADDR_FLAGS_W-1:0]                             w_addrA_val_flags;
    mac_t                                                w_addrA_val_mac_type;
    logic [VIR_ADDR_W-1:0]                               w_addrB_val_addr;
    logic [XLEN-1:0]                                     w_addrB_val_tid;
    logic [ADDR_FLAGS_W-1:0]                             w_addrB_val_flags;
    mac_t                                                w_addrB_val_mac_type;
    logic [VIR_ADDR_W-1:0]                               w_addrD_val_addr;
    logic [XLEN-1:0]                                     w_addrD_val_tid;
    logic [VEC_W-1:0]                                    w_out_val_data;

    assign w_addrA_val_addr     = w_addrA_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W-1 : XLEN+MAC_W+ADDR_FLAGS_W];
    assign w_addrA_dense        = w_addrA_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W];
    assign w_addrA_reused       = w_addrA_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1];
    assign w_addrA_val_tid      = w_addrA_head_data[XLEN+MAC_W+ADDR_FLAGS_W-1 : MAC_W+ADDR_FLAGS_W];
    assign w_addrA_val_mac_type = mac_t'(w_addrA_head_data[MAC_W+ADDR_FLAGS_W-1:ADDR_FLAGS_W]);
    assign w_addrA_val_flags    = w_addrA_head_data[ADDR_FLAGS_W-1:0];
    assign w_addrB_val_addr     = w_addrB_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W-1 : XLEN+MAC_W+ADDR_FLAGS_W];
    assign w_addrB_dense        = w_addrB_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W];
    assign w_addrB_reused       = w_addrB_head_data[VIR_ADDR_W+XLEN+MAC_W+ADDR_FLAGS_W+1];
    assign w_addrB_val_tid      = w_addrB_head_data[XLEN+MAC_W+ADDR_FLAGS_W-1 : MAC_W+ADDR_FLAGS_W];
    assign w_addrB_val_mac_type = mac_t'(w_addrB_head_data[MAC_W+ADDR_FLAGS_W-1:ADDR_FLAGS_W]);
    assign w_addrB_val_flags    = w_addrB_head_data[ADDR_FLAGS_W-1:0];
    assign w_addrD_val_addr     = w_addrD_head_data[VIR_ADDR_W+XLEN-1 : XLEN];
    assign w_addrD_val_tid      = w_addrD_head_data[XLEN-1 : 0];
    assign w_out_val_data       = w_out_head_data;
    assign o_req_we[0]          = 1'b0;
    assign o_req_is_lr[0]       = 1'b0;
    assign o_req_is_sc[0]       = 1'b0;
    assign o_req_wdata[0]       = '0;
    assign o_req_wstrb[0]       = '0;
    assign o_req_valid[0]       = w_addrA_deq_ready && !w_addrA_reused && w_req_fifo_enq_ready[0];
    assign o_req_addr[0]        = w_addrA_val_addr;
    assign o_req_thrd[0]        = w_addrA_val_tid;
    assign w_req_fifo_enq_valid[0] = o_req_valid[0] && i_req_ready[0];
    assign w_req_fifo_enq_data[0]  = '{
        tid:      o_req_thrd[0],
        dense:    w_addrA_dense,
        mac_type: w_addrA_val_mac_type,
        flags:    w_addrA_val_flags,
        addr:     o_req_addr[0]
    };
    assign w_addrA_deq_valid       = w_addrA_reused
                                   ? (w_addrA_deq_ready && !w_req_fifo_deq_ready[0] && w_drvA_enq_ready)
                                   : w_req_fifo_enq_valid[0];
    assign o_req_we[1]             = 1'b0;
    assign o_req_is_lr[1]          = 1'b0;
    assign o_req_is_sc[1]          = 1'b0;
    assign o_req_wdata[1]          = '0;
    assign o_req_wstrb[1]          = '0;
    assign o_req_valid[1]          = w_addrB_deq_ready && !w_addrB_reused && w_req_fifo_enq_ready[1];
    assign o_req_addr[1]           = w_addrB_val_addr;
    assign o_req_thrd[1]           = w_addrB_val_tid;
    assign w_req_fifo_enq_valid[1] = o_req_valid[1] && i_req_ready[1];
    assign w_req_fifo_enq_data[1]  = '{
        tid:      o_req_thrd[1],
        dense:    w_addrB_dense,
        mac_type: w_addrB_val_mac_type,
        flags:    w_addrB_val_flags,
        addr:     o_req_addr[1]
    };
    assign w_addrB_deq_valid       = w_addrB_reused
                                   ? (w_addrB_deq_ready && !w_req_fifo_deq_ready[1] && w_drvB_enq_ready)
                                   : w_req_fifo_enq_valid[1];
    assign o_req_we[2]             = 1'b1;
    assign o_req_is_lr[2]          = 1'b0;
    assign o_req_is_sc[2]          = 1'b0;
    assign o_req_valid[2]          = w_addrD_deq_ready && w_out_deq_ready;
    assign o_req_addr[2]           = w_addrD_val_addr;
    assign o_req_thrd[2]           = w_addrD_val_tid;
    assign o_req_wdata[2]          = w_out_val_data;
    assign o_req_wstrb[2]          = {XLEN/8{1'b1}};
    assign w_addrD_deq_valid       = o_req_valid[2] && i_req_ready[2];
    assign w_out_deq_valid         = w_addrD_deq_valid;
    assign o_resp_ready[2]         = 1'b1;

    always_comb begin
        w_req_fifo_deq_valid[0] = 1'b0;
        w_req_fifo_deq_valid[1] = 1'b0;
        o_resp_ready[0]         = w_req_fifo_deq_ready[0] && w_drvA_enq_ready;
        o_resp_ready[1]         = w_req_fifo_deq_ready[1] && w_drvB_enq_ready;
        w_drvA_enq_valid        = 1'b0;
        w_drvA_enq_data         = '0;
        w_drvB_enq_valid        = 1'b0;
        w_drvB_enq_data         = '0;

        if (w_addrA_reused && w_addrA_deq_ready && !w_req_fifo_deq_ready[0]) begin
            w_drvA_enq_valid = 1'b1;
            w_drvA_enq_data  = {1'b1, w_addrA_dense, w_addrA_val_addr, VEC_W'(0), w_addrA_val_tid,
                                w_addrA_val_mac_type, w_addrA_val_flags};
        end
        if (w_addrB_reused && w_addrB_deq_ready && !w_req_fifo_deq_ready[1]) begin
            w_drvB_enq_valid = 1'b1;
            w_drvB_enq_data  = {1'b1, w_addrB_dense, w_addrB_val_addr, VEC_W'(0), w_addrB_val_tid,
                                w_addrB_val_mac_type, w_addrB_val_flags};
        end

        if (i_resp_valid[0] && o_resp_ready[0]) begin
            w_req_fifo_deq_valid[0] = 1'b1;
            w_drvA_enq_valid        = 1'b1;
            w_drvA_enq_data         = {1'b0, w_req_fifo_head_data[0].dense,
                                       w_req_fifo_head_data[0].addr, i_resp_rdata[0],
                                       w_req_fifo_head_data[0].tid,
                                       w_req_fifo_head_data[0].mac_type,
                                       w_req_fifo_head_data[0].flags};
        end
        if (i_resp_valid[1] && o_resp_ready[1]) begin
            w_req_fifo_deq_valid[1] = 1'b1;
            w_drvB_enq_valid        = 1'b1;
            w_drvB_enq_data         = {1'b0, w_req_fifo_head_data[1].dense,
                                       w_req_fifo_head_data[1].addr, i_resp_rdata[1],
                                       w_req_fifo_head_data[1].tid,
                                       w_req_fifo_head_data[1].mac_type,
                                       w_req_fifo_head_data[1].flags};
        end
    end

    circular_buffer #(
        .DEPTH(RES_BUFF_D),
        .WIDTH(VEC_W)
    ) output_buff (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .o_head_data    (w_out_head_data),
        .o_deq_ready    (w_out_deq_ready),
        .i_deq_valid    (w_out_deq_valid),
        .i_enq_tail_data(w_out_enq_data),
        .i_enq_valid    (w_out_enq_valid),
        .o_enq_ready    (w_out_enq_ready),
        .o_full         (),
        .o_empty        (),
        .o_level        (w_out_level),
        .i_clr_n        (1'b1)
    );

    circular_buffer #(
        .DEPTH(OP_BUFF_D),
        .WIDTH(VIR_ADDR_W + VEC_W + XLEN + MAC_W + ADDR_FLAGS_W + 2)
    ) drvA_buff (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .o_head_data    (w_drvA_head_data),
        .o_deq_ready    (w_drvA_deq_ready),
        .i_deq_valid    (w_drvA_deq_valid),
        .i_enq_tail_data(w_drvA_enq_data),
        .i_enq_valid    (w_drvA_enq_valid),
        .o_enq_ready    (w_drvA_enq_ready),
        .o_full         (),
        .o_empty        (),
        .o_level        (w_drvA_level),
        .i_clr_n        (1'b1)
    );

    circular_buffer #(
        .DEPTH(OP_BUFF_D),
        .WIDTH(VIR_ADDR_W + VEC_W + XLEN + MAC_W + ADDR_FLAGS_W + 2)
    ) drvB_buff (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .o_head_data    (w_drvB_head_data),
        .o_deq_ready    (w_drvB_deq_ready),
        .i_deq_valid    (w_drvB_deq_valid),
        .i_enq_tail_data(w_drvB_enq_data),
        .i_enq_valid    (w_drvB_enq_valid),
        .o_enq_ready    (w_drvB_enq_ready),
        .o_full         (),
        .o_empty        (),
        .o_level        (w_drvB_level),
        .i_clr_n        (1'b1)
    );

    for (genvar p = 0; p < 2; p++) begin : gen_req_fifos
        circular_buffer #(
            .DEPTH(32),
            .WIDTH($bits(read_meta_t))
        ) u_read_req_buffer (
            .i_clk          (i_clk),
            .i_rst_n        (i_rst_n),
            .o_head_data    (w_req_fifo_head_data[p]),
            .o_deq_ready    (w_req_fifo_deq_ready[p]),
            .i_deq_valid    (w_req_fifo_deq_valid[p]),
            .i_enq_tail_data(w_req_fifo_enq_data[p]),
            .i_enq_valid    (w_req_fifo_enq_valid[p]),
            .o_enq_ready    (w_req_fifo_enq_ready[p]),
            .o_full         (),
            .o_empty        (),
            .o_level        (w_req_level[p]),
            .i_clr_n        (1'b1)
        );
    end
    /*  --Memory Driver */



    /* Systolic Array Driver--- */
    logic                             w_actrl_val;
    logic [$clog2(sys_cnfg_pkg::K+1)-1:0] w_ac_k2;
    logic                             w_core_a_valid;
    logic                             w_core_b_valid;
    logic                             w_a_ready;
    logic                             w_b_ready;
    logic [ADDR_FLAGS_W-1:0]          w_core_flags;
    logic                             w_core_start;
    logic                             w_core_last;
    logic                             w_core_end;
    logic                             w_core_fire;
    logic                             w_core_a_fire;
    logic                             w_core_b_fire;
    logic                             w_op_done;
    logic [M*WIDTH_CD-1:0]            w_d;
    logic                             w_d_valid;
    logic                             w_d_ready;

    assign w_drvA_reused    = w_drvA_head_data[VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1];
    assign w_drvB_reused    = w_drvB_head_data[VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W+1];
    assign w_core_dense     = w_drvB_deq_ready
                            ? w_drvB_head_data[VIR_ADDR_W+VEC_W+XLEN+MAC_W+ADDR_FLAGS_W]
                            : w_head_is_dense;
    assign w_actrl_val      = w_head_is_op || w_drvA_deq_ready || w_drvB_deq_ready;
    assign w_ac_k2          = w_core_dense ? get_cmd_b_size(w_head_cmd) : $clog2(sys_cnfg_pkg::K+1)'(1);
    assign w_core_a_valid   = w_drvA_deq_ready && !w_drvA_reused;
    assign w_core_b_valid   = w_drvB_deq_ready && !w_drvB_reused;
    assign w_core_a_fire    = w_core_a_valid && w_a_ready;
    assign w_core_b_fire    = w_core_b_valid && w_b_ready;
    assign w_core_fire      = w_core_a_fire || w_core_b_fire;
    assign w_drvA_deq_valid = w_drvA_deq_ready && (w_drvA_reused ? w_core_fire : w_core_a_fire);
    assign w_drvB_deq_valid = w_drvB_deq_ready && (w_drvB_reused ? w_core_fire : w_core_b_fire);
    assign w_core_flags     = w_drvB_head_data[ADDR_FLAGS_W-1:0];
    assign w_core_start     = w_core_flags[0] && (w_core_flags != ADDR_FLAGS_CONTINUE);
    assign w_core_last      = w_core_flags[1] && (w_core_flags != ADDR_FLAGS_CONTINUE);
    assign w_core_end       = w_core_flags[2] && (w_core_flags != ADDR_FLAGS_CONTINUE);
    assign w_op_done        = w_core_end && w_core_fire;
    assign w_done_a         = !w_head_is_dense && !is_cmd_last(w_head_cmd)
                            ? r_lag_done_a_seen
                            : w_op_done;
    assign w_done_b         = !w_head_is_dense && !is_cmd_last(w_head_cmd)
                            ? r_lag_done_b_seen
                            : w_op_done;
    assign w_out_enq_valid  = w_d_valid;
    assign w_out_enq_data   = w_d;
    assign w_d_ready        = w_out_enq_ready;

    mmacu_core_v2 u_mmacu_core (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .i_dense    (w_core_dense),
        .i_k2       (w_ac_k2),
        .i_mac_type (mac_t'(w_drvB_head_data[MAC_W+ADDR_FLAGS_W-1:ADDR_FLAGS_W])),
        .i_start    (w_core_start),
        .i_last     (w_core_last),
        .i_end      (w_core_end),
        .i_a        (w_drvA_head_data[VEC_W+XLEN+MAC_W+ADDR_FLAGS_W-1:XLEN+MAC_W+ADDR_FLAGS_W]),
        .i_b        (w_drvB_head_data[VEC_W+XLEN+MAC_W+ADDR_FLAGS_W-1:XLEN+MAC_W+ADDR_FLAGS_W]),
        .i_a_valid  (w_core_a_valid),
        .i_b_valid  (w_core_b_valid),
        .o_a_ready  (w_a_ready),
        .o_b_ready  (w_b_ready),
        .o_d        (w_d),
        .o_d_valid  (w_d_valid),
        .i_d_ready  (w_d_ready)
    );
    /*  ---Systolic Array Driver */


    /* Performance counters---  */
`ifndef PERF_EN
    typedef struct packed {
        logic [XLEN-1:0] freestanding_cycles;
        logic [XLEN-1:0] last_job_accel_cycles;
        logic [XLEN-1:0] last_job_mac_cycles;
        logic [XLEN-1:0] last_job_stall_cycles;
        logic [XLEN-1:0] last_job_a_vecs_loaded;
        logic [XLEN-1:0] last_job_b_vecs_loaded;
        logic [XLEN-1:0] last_job_d_vecs_stored;
        logic [XLEN-1:0] last_job_dense_macs;
        logic [XLEN-1:0] last_job_native_macs;
        logic [XLEN-1:0] fifo_levels;  // {padding, output, padding, addrD, addrB, addrA, cmd}
    } perf_sys_core_t;

    perf_sys_core_t  perf_vec;
    logic [XLEN-1:0] job_accel_cycles;
    logic [XLEN-1:0] job_mac_cycles;
    logic [XLEN-1:0] job_stall_cycles;
    logic [XLEN-1:0] job_a_vecs_loaded;
    logic [XLEN-1:0] job_b_vecs_loaded;
    logic [XLEN-1:0] job_d_vecs_stored;
    logic [XLEN-1:0] job_dense_macs;
    logic [XLEN-1:0] job_native_macs;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            perf_vec               <= '0;
            job_accel_cycles       <= '0;
            job_mac_cycles         <= '0;
            job_stall_cycles       <= '0;
            job_a_vecs_loaded      <= '0;
            job_b_vecs_loaded      <= '0;
            job_d_vecs_stored      <= '0;
            job_dense_macs         <= '0;
            job_native_macs        <= '0;
        end else begin
            if (!w_busy)
                perf_vec.freestanding_cycles <= perf_vec.freestanding_cycles + XLEN'(1);

            if (!r_busy && w_busy) begin
                job_accel_cycles  <= XLEN'(1);
                job_mac_cycles    <= XLEN'(w_core_fire);
                job_stall_cycles  <= XLEN'(w_actrl_val && !w_core_fire);
                job_a_vecs_loaded <= XLEN'(o_req_valid[0] && i_req_ready[0]);
                job_b_vecs_loaded <= XLEN'(o_req_valid[1] && i_req_ready[1]);
                job_d_vecs_stored <= XLEN'(o_req_valid[2] && i_req_ready[2]);
                job_dense_macs    <= XLEN'(w_core_fire && w_core_dense);
                job_native_macs   <= XLEN'(w_core_fire && !w_core_dense);
            end else if (w_busy) begin
                job_accel_cycles  <= job_accel_cycles + XLEN'(1);
                job_mac_cycles    <= job_mac_cycles + XLEN'(w_core_fire);
                job_stall_cycles  <= job_stall_cycles + XLEN'(w_actrl_val && !w_core_fire);
                job_a_vecs_loaded <= job_a_vecs_loaded + XLEN'(o_req_valid[0] && i_req_ready[0]);
                job_b_vecs_loaded <= job_b_vecs_loaded + XLEN'(o_req_valid[1] && i_req_ready[1]);
                job_d_vecs_stored <= job_d_vecs_stored + XLEN'(o_req_valid[2] && i_req_ready[2]);
                job_dense_macs    <= job_dense_macs + XLEN'(w_core_fire && w_core_dense);
                job_native_macs   <= job_native_macs + XLEN'(w_core_fire && !w_core_dense);
            end

            if (r_busy && !w_busy) begin
                perf_vec.last_job_accel_cycles  <= job_accel_cycles;
                perf_vec.last_job_mac_cycles    <= job_mac_cycles;
                perf_vec.last_job_stall_cycles  <= job_stall_cycles;
                perf_vec.last_job_a_vecs_loaded <= job_a_vecs_loaded;
                perf_vec.last_job_b_vecs_loaded <= job_b_vecs_loaded;
                perf_vec.last_job_d_vecs_stored <= job_d_vecs_stored;
                perf_vec.last_job_dense_macs    <= job_dense_macs;
                perf_vec.last_job_native_macs   <= job_native_macs;
            end

            perf_vec.fifo_levels <= {
                8'(0), 8'(w_out_level), 16'(0), 8'(w_addrD_level),
                8'(w_addrB_level), 8'(w_addrA_level), 8'(w_cmd_level)
            };
        end
    end
`ifndef SYNTHESIS
    function automatic void get_sys_core_perf_vec(output bit [10*XLEN-1:0] value);
        value = perf_vec;
    endfunction
    export "DPI-C" function get_sys_core_perf_vec;
`endif
`endif
    /*  ---Performance counters */
endmodule: sys_core

`default_nettype wire
