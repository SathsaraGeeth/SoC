`timescale 1ns/1ps
`default_nettype none

import core_pkg::*;
import memory_pkg::*;
import topology_pkg::*;
import isa_pkg::*;
import soc_pkg::*;

module router #(
    parameter int C_X = 0,
    parameter int C_Y = 0
) (
    input  logic                                i_clk,
    input  logic                                i_rst_n,

    // Core Instruction Port
    input  logic                                i_req_instr_valid,
    output logic                                o_req_instr_ready,
    input  logic [VIR_ADDR_W-1:0]               i_req_instr_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]     i_req_instr_thrd_id,
    input  logic [1:0]                          i_req_instr_priv,
    
    output logic                                o_resp_instr_valid,
    input  logic                                i_resp_instr_ready,
    output logic [XLEN-1:0]                     o_resp_instr,
    output logic [$clog2(NUM_HW_THRDS)-1:0]     o_resp_instr_thrd_id,

    // Core Data Port
    input  logic                                i_req_data_valid,
    output logic                                o_req_data_ready,
    input  logic [VIR_ADDR_W-1:0]               i_req_data_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]     i_req_data_thrd_id,
    input  logic [1:0]                          i_req_data_priv,
    input  logic                                i_req_data_rw,
    input  logic                                i_req_data_lq,
    input  logic                                i_req_data_sc,
    input  logic [XLEN/8-1:0]                   i_req_data_wstrb,
    input  logic [XLEN-1:0]                     i_req_data_wdata,
    
    output logic                                o_resp_data_valid,
    input  logic                                i_resp_data_ready,
    output logic [XLEN-1:0]                     o_resp_data_rdata,
    output logic                                o_resp_data_sc_ok,
    output logic [$clog2(NUM_HW_THRDS)-1:0]     o_resp_data_thrd_id,

    // Local MMIO port. Address decoding and memory/MMIO response ordering are
    // owned by the router; the SoC only arbitrates the peripheral endpoints.
    output logic                                o_mmio_req_valid,
    input  logic                                i_mmio_req_ready,
    output logic [VIR_ADDR_W-1:0]               o_mmio_req_addr,
    output logic [$clog2(NUM_HW_THRDS)-1:0]     o_mmio_req_thrd_id,
    output logic [1:0]                          o_mmio_req_priv,
    output logic                                o_mmio_req_rw,
    output logic [XLEN/8-1:0]                   o_mmio_req_wstrb,
    output logic [XLEN-1:0]                     o_mmio_req_wdata,
    input  logic                                i_mmio_resp_valid,
    output logic                                o_mmio_resp_ready,
    input  logic [XLEN-1:0]                     i_mmio_resp_rdata,
    input  logic                                i_mmio_resp_sc_ok,
    input  logic [$clog2(NUM_HW_THRDS)-1:0]     i_mmio_resp_thrd_id,

    // Core page-message interface
    input  logic                                i_core_page_msg_valid,
    input  logic [PAGE_MSG_W-1:0]               i_core_page_msg,
    output logic                                o_core_page_msg_ready,
    output logic                                o_core_page_msg_instr_valid,
    output logic [PAGE_MSG_W-1:0]               o_core_page_msg_instr,
    input  logic                                i_core_page_msg_instr_ready,
    output logic                                o_core_page_msg_data_valid,
    output logic [PAGE_MSG_W-1:0]               o_core_page_msg_data,
    input  logic                                i_core_page_msg_data_ready,

    // Directional page-message ports (0=N, 1=E, 2=S, 3=W)
    output logic                                o_mem_page_msg_valid       [3:0],
    output logic [PAGE_MSG_W-1:0]               o_mem_page_msg             [3:0],
    input  logic                                i_mem_page_msg_ready       [3:0],
    input  logic                                i_mem_page_msg_instr_valid [3:0],
    input  logic [PAGE_MSG_W-1:0]               i_mem_page_msg_instr       [3:0],
    output logic                                o_mem_page_msg_instr_ready [3:0],
    input  logic                                i_mem_page_msg_data_valid  [3:0],
    input  logic [PAGE_MSG_W-1:0]               i_mem_page_msg_data        [3:0],
    output logic                                o_mem_page_msg_data_ready  [3:0],

    // Memory Instruction Ports (0=N, 1=E, 2=S, 3=W)
    output logic                                o_mem_req_instr_valid  [3:0],
    input  logic                                i_mem_req_instr_ready  [3:0],
    output logic [VIR_ADDR_W-1:0]               o_mem_req_instr_addr   [3:0],
    output logic [$clog2(NUM_HW_THRDS)-1:0]     o_mem_req_instr_thrd_id[3:0],
    output logic [1:0]                          o_mem_req_instr_priv   [3:0],
    
    input  logic                                i_mem_resp_instr_valid [3:0],
    output logic                                o_mem_resp_instr_ready [3:0],
    input  logic [XLEN-1:0]                     i_mem_resp_instr_rdata [3:0],
    input  logic [$clog2(NUM_HW_THRDS)-1:0]     i_mem_resp_instr_thrd_id[3:0],

    // Memory Data Ports (0=N, 1=E, 2=S, 3=W)
    output logic                                o_mem_req_data_valid   [3:0],
    input  logic                                i_mem_req_data_ready   [3:0],
    output logic [VIR_ADDR_W-1:0]               o_mem_req_data_addr    [3:0],
    output logic [$clog2(NUM_HW_THRDS)-1:0]     o_mem_req_data_thrd_id [3:0],
    output logic [1:0]                          o_mem_req_data_priv    [3:0],
    output logic                                o_mem_req_data_rw      [3:0],
    output logic                                o_mem_req_data_lq      [3:0],
    output logic                                o_mem_req_data_sc      [3:0],
    output logic [XLEN/8-1:0]                   o_mem_req_data_wstrb   [3:0],
    output logic [XLEN-1:0]                     o_mem_req_data_wdata   [3:0],
    
    input  logic                                i_mem_resp_data_valid  [3:0],
    output logic                                o_mem_resp_data_ready  [3:0],
    input  logic [XLEN-1:0]                     i_mem_resp_data_rdata  [3:0],
    input  logic                                i_mem_resp_data_sc_ok  [3:0],
    input  logic [$clog2(NUM_HW_THRDS)-1:0]     i_mem_resp_data_thrd_id[3:0]
);

    localparam int REGION_OFFSET_BITS = VIR_ADDR_W - 2 * MESH_COORD_BITS;

    logic                       w_page_instr_valid;
    logic [PAGE_MSG_W-1:0]      w_page_instr;
    logic                       w_page_instr_ready;
    logic                       w_page_data_valid;
    logic [PAGE_MSG_W-1:0]      w_page_data;
    logic                       w_page_data_ready;
    logic                       r_page_instr_valid;
    logic [PAGE_MSG_W-1:0]      r_page_instr;
    logic                       r_page_data_valid;
    logic [PAGE_MSG_W-1:0]      r_page_data;

    function automatic logic [1:0] get_local_dir();
        return (C_X % 2 == 0) ? 2'd1 : 2'd3; // local boot/data region: East/West
    endfunction

    // Page messages target the core's local memory. Incoming messages retain
    // separate instruction/data channels and use a fixed N/E/S/W priority.
    always_comb begin
        logic instr_selected;
        logic data_selected;
        logic [1:0] local_dir;

        local_dir = get_local_dir();
        instr_selected = 1'b0;
        data_selected = 1'b0;
        o_core_page_msg_ready = i_mem_page_msg_ready[local_dir];
        w_page_instr_valid = 1'b0;
        w_page_instr = '0;
        w_page_data_valid = 1'b0;
        w_page_data = '0;

        for (int direction = 3; direction >= 0; direction--) begin
            o_mem_page_msg_valid[direction] = i_core_page_msg_valid && (2'(direction) == local_dir);
            o_mem_page_msg[direction] = i_core_page_msg;
            o_mem_page_msg_instr_ready[direction] = 1'b0;
            o_mem_page_msg_data_ready[direction] = 1'b0;

            if (!instr_selected && i_mem_page_msg_instr_valid[direction]) begin
                instr_selected = 1'b1;
                w_page_instr_valid = 1'b1;
                w_page_instr = i_mem_page_msg_instr[direction];
                o_mem_page_msg_instr_ready[direction] = w_page_instr_ready;
            end
            if (!data_selected && i_mem_page_msg_data_valid[direction]) begin
                data_selected = 1'b1;
                w_page_data_valid = 1'b1;
                w_page_data = i_mem_page_msg_data[direction];
                o_mem_page_msg_data_ready[direction] = w_page_data_ready;
            end
        end
    end

    assign w_page_instr_ready             = !r_page_instr_valid || i_core_page_msg_instr_ready;
    assign w_page_data_ready              = !r_page_data_valid || i_core_page_msg_data_ready;
    assign o_core_page_msg_instr_valid    = r_page_instr_valid;
    assign o_core_page_msg_instr          = r_page_instr;
    assign o_core_page_msg_data_valid     = r_page_data_valid;
    assign o_core_page_msg_data           = r_page_data;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_page_instr_valid <= 1'b0;
            r_page_instr       <= '0;
            r_page_data_valid  <= 1'b0;
            r_page_data        <= '0;
        end else begin
            if (w_page_instr_ready) begin
                r_page_instr_valid <= w_page_instr_valid;
                if (w_page_instr_valid) r_page_instr <= w_page_instr;
            end
            if (w_page_data_ready) begin
                r_page_data_valid <= w_page_data_valid;
                if (w_page_data_valid) r_page_data <= w_page_data;
            end
        end
    end

    function automatic logic [1:0] get_dir(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        logic [MESH_COORD_BITS-1:0] row;
        logic [MESH_COORD_BITS-1:0] col;
        row = addr[REGION_OFFSET_BITS + MESH_COORD_BITS +: MESH_COORD_BITS];
        col = addr[REGION_OFFSET_BITS +: MESH_COORD_BITS];

        if (priv == PRIV_MODE_U) begin
            return get_local_dir();
        end

        if (row == '0 && col == '0) begin
            return get_local_dir();
        end
        
        if (row == MESH_COORD_BITS'(C_Y - 1) && col == MESH_COORD_BITS'(C_X)) begin
            return 2'd0; // North
        end else if (row == MESH_COORD_BITS'(C_Y) && col == MESH_COORD_BITS'(C_X + 1)) begin
            return 2'd1; // East
        end else if (row == MESH_COORD_BITS'(C_Y + 1) && col == MESH_COORD_BITS'(C_X)) begin
            return 2'd2; // South
        end else if (row == MESH_COORD_BITS'(C_Y) && col == MESH_COORD_BITS'(C_X - 1)) begin
            return 2'd3; // West
        end else begin
            return 2'd0; 
        end
    endfunction

    function automatic logic is_valid_dir(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        logic [MESH_COORD_BITS-1:0] row;
        logic [MESH_COORD_BITS-1:0] col;
        row = addr[REGION_OFFSET_BITS + MESH_COORD_BITS +: MESH_COORD_BITS];
        col = addr[REGION_OFFSET_BITS +: MESH_COORD_BITS];

        if (priv == PRIV_MODE_U) begin
            return 1'b1;
        end

        if (row == '0 && col == '0) begin
            return 1'b1;
        end
        
        return (row == MESH_COORD_BITS'(C_Y - 1) && col == MESH_COORD_BITS'(C_X)) ||
               (row == MESH_COORD_BITS'(C_Y) && col == MESH_COORD_BITS'(C_X + 1)) ||
               (row == MESH_COORD_BITS'(C_Y + 1) && col == MESH_COORD_BITS'(C_X)) ||
               (row == MESH_COORD_BITS'(C_Y) && col == MESH_COORD_BITS'(C_X - 1));
    endfunction

    // --------------------------------------------------------
    // Instruction Routing
    // --------------------------------------------------------
    logic [1:0] instr_dir;
    logic       instr_valid_dir;
    assign instr_dir = get_dir(i_req_instr_addr, i_req_instr_priv);
    assign instr_valid_dir = is_valid_dir(i_req_instr_addr, i_req_instr_priv);

    // Simulation checks for out-of-bounds routing
    always_ff @(posedge i_clk) begin
        if (i_req_instr_valid && !instr_valid_dir && i_rst_n) begin
            $fatal(1, "Out of bounds instruction address routing at Core (%0d,%0d): %h", C_X, C_Y, i_req_instr_addr);
        end
    end

    logic instr_rob_enq_ready;
    logic instr_rob_deq_ready;
    logic [1:0] instr_rob_head_dir;
    logic       instr_resp_buf_ready;
    logic       instr_resp_capture;
    logic       r_resp_instr_valid;
    logic [XLEN-1:0] r_resp_instr;
    logic [$clog2(NUM_HW_THRDS)-1:0] r_resp_instr_thrd_id;
    logic                   r_mem_resp_instr_valid   [3:0];
    logic [XLEN-1:0]        r_mem_resp_instr_rdata   [3:0];
    logic [CORE_THRD_W-1:0] r_mem_resp_instr_thrd_id [3:0];
    logic                   w_mem_resp_instr_ready   [3:0];

    assign instr_resp_buf_ready = !r_resp_instr_valid || i_resp_instr_ready;
    assign instr_resp_capture = instr_resp_buf_ready &&
                                instr_rob_deq_ready &&
                                r_mem_resp_instr_valid[instr_rob_head_dir];

    circular_buffer #(
        .DEPTH(4),
        .WIDTH(2)
    ) instr_rob (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .o_head_data(instr_rob_head_dir),
        .o_deq_ready(instr_rob_deq_ready),
        .i_deq_valid(instr_resp_capture),
        .i_enq_tail_data(instr_dir),
        .i_enq_valid(i_req_instr_valid && instr_rob_enq_ready && i_mem_req_instr_ready[instr_dir] && instr_valid_dir),
        .o_enq_ready(instr_rob_enq_ready),
        .o_full(),
        .o_empty(),
        .o_level(),
        .i_clr_n(1'b1)
    );

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            o_mem_req_instr_valid[i]   = (2'(i) == instr_dir) ? (i_req_instr_valid && instr_rob_enq_ready && instr_valid_dir) : 1'b0;
            o_mem_req_instr_addr[i]    = i_req_instr_addr;
            o_mem_req_instr_thrd_id[i] = i_req_instr_thrd_id;
            o_mem_req_instr_priv[i]    = i_req_instr_priv;
            
            w_mem_resp_instr_ready[i] = (2'(i) == instr_rob_head_dir) ? (instr_resp_buf_ready && instr_rob_deq_ready) : 1'b0;
            o_mem_resp_instr_ready[i] = !r_mem_resp_instr_valid[i] || w_mem_resp_instr_ready[i];
        end
        o_req_instr_ready = i_mem_req_instr_ready[instr_dir] && instr_rob_enq_ready && instr_valid_dir;
        
        o_resp_instr_valid = r_resp_instr_valid;
        o_resp_instr       = r_resp_instr;
        o_resp_instr_thrd_id = r_resp_instr_thrd_id;
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_resp_instr_valid <= 1'b0;
            r_resp_instr <= '0;
            r_resp_instr_thrd_id <= '0;
        end else if (instr_resp_capture) begin
            r_resp_instr_valid <= 1'b1;
            r_resp_instr <= r_mem_resp_instr_rdata[instr_rob_head_dir];
            r_resp_instr_thrd_id <= r_mem_resp_instr_thrd_id[instr_rob_head_dir];
        end else if (i_resp_instr_ready) begin
            r_resp_instr_valid <= 1'b0;
        end
    end

    // --------------------------------------------------------
    // Data Routing
    // --------------------------------------------------------
    logic [1:0] data_dir;
    logic       data_valid_dir;
    assign data_dir = get_dir(i_req_data_addr, i_req_data_priv);
    assign data_valid_dir = is_valid_dir(i_req_data_addr, i_req_data_priv);

    always_ff @(posedge i_clk) begin
        if (i_req_data_valid && !data_is_mmio && !data_valid_dir && i_rst_n) begin
            $fatal(1, "Out of bounds data address routing at Core (%0d,%0d): addr=%h thrd=%0d priv=%0d rw=%0d wstrb=%b wdata=%h",
                C_X, C_Y, i_req_data_addr, i_req_data_thrd_id, i_req_data_priv, i_req_data_rw,
                i_req_data_wstrb, i_req_data_wdata);
        end
    end

    logic data_rob_enq_ready;
    logic data_rob_deq_ready;
    localparam logic [2:0] DATA_TARGET_MMIO = 3'd4;
    logic [2:0] data_target;
    logic [2:0] data_rob_head_target;
    logic       data_is_mmio;
    logic       data_target_ready;
    logic       data_head_resp_valid;
    logic       data_resp_buf_ready;
    logic       data_resp_capture;
    logic       data_fault_capture;
    generic_page_msg_t data_page_msg;
    logic       r_resp_data_valid;
    logic [XLEN-1:0] r_resp_data_rdata;
    logic       r_resp_data_sc_ok;
    logic [$clog2(NUM_HW_THRDS)-1:0] r_resp_data_thrd_id;
    logic                   r_mem_resp_data_valid   [3:0];
    logic [XLEN-1:0]        r_mem_resp_data_rdata   [3:0];
    logic                   r_mem_resp_data_sc_ok   [3:0];
    logic [CORE_THRD_W-1:0] r_mem_resp_data_thrd_id [3:0];
    logic                   w_mem_resp_data_ready   [3:0];

    assign data_resp_buf_ready = !r_resp_data_valid || i_resp_data_ready;
    assign data_is_mmio = is_soc_mmio_addr(i_req_data_addr, i_req_data_priv);
    assign data_target = data_is_mmio ? DATA_TARGET_MMIO : {1'b0, data_dir};
    assign data_target_ready = data_is_mmio ? i_mmio_req_ready : i_mem_req_data_ready[data_dir];
    assign data_head_resp_valid = (data_rob_head_target == DATA_TARGET_MMIO) ? i_mmio_resp_valid : r_mem_resp_data_valid[data_rob_head_target[1:0]];
    assign data_resp_capture = data_resp_buf_ready &&
                               data_rob_deq_ready &&
                               data_head_resp_valid;
    assign data_page_msg = r_page_data;
    assign data_fault_capture = data_rob_deq_ready &&
                                data_rob_head_target != DATA_TARGET_MMIO &&
                                r_page_data_valid &&
                                data_page_msg.msg_type == PAGE_MSG_FAULT &&
                                i_core_page_msg_data_ready;

    circular_buffer #(
        .DEPTH(4),
        .WIDTH(3)
    ) data_rob (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .o_head_data(data_rob_head_target),
        .o_deq_ready(data_rob_deq_ready),
        .i_deq_valid(data_resp_capture || data_fault_capture),
        .i_enq_tail_data(data_target),
        .i_enq_valid(i_req_data_valid && data_rob_enq_ready &&
                     data_target_ready && (data_is_mmio || data_valid_dir)),
        .o_enq_ready(data_rob_enq_ready),
        .o_full(),
        .o_empty(),
        .o_level(),
        .i_clr_n(1'b1)
    );

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            o_mem_req_data_valid[i]   = !data_is_mmio && (2'(i) == data_dir) ?
                                        (i_req_data_valid && data_rob_enq_ready && data_valid_dir) : 1'b0;
            o_mem_req_data_addr[i]    = i_req_data_addr;
            o_mem_req_data_thrd_id[i] = i_req_data_thrd_id;
            o_mem_req_data_priv[i]    = i_req_data_priv;
            o_mem_req_data_rw[i]      = i_req_data_rw;
            o_mem_req_data_lq[i]      = i_req_data_lq;
            o_mem_req_data_sc[i]      = i_req_data_sc;
            o_mem_req_data_wstrb[i]   = i_req_data_wstrb;
            o_mem_req_data_wdata[i]   = i_req_data_wdata;
            
            w_mem_resp_data_ready[i] = (data_rob_head_target != DATA_TARGET_MMIO) && (2'(i) == data_rob_head_target[1:0]) ? (data_resp_buf_ready && data_rob_deq_ready) : 1'b0;
            o_mem_resp_data_ready[i] = !r_mem_resp_data_valid[i] || w_mem_resp_data_ready[i];
        end
        o_mmio_req_valid = data_is_mmio && i_req_data_valid && data_rob_enq_ready;
        o_mmio_resp_ready = (data_rob_head_target == DATA_TARGET_MMIO) && data_resp_buf_ready && data_rob_deq_ready;
        o_mmio_req_addr = i_req_data_addr;
        o_mmio_req_thrd_id = i_req_data_thrd_id;
        o_mmio_req_priv = i_req_data_priv;
        o_mmio_req_rw = i_req_data_rw;
        o_mmio_req_wstrb = i_req_data_wstrb;
        o_mmio_req_wdata = i_req_data_wdata;
        o_req_data_ready = data_target_ready && data_rob_enq_ready &&
                           (data_is_mmio || data_valid_dir);
        
        o_resp_data_valid = r_resp_data_valid;
        o_resp_data_rdata = r_resp_data_rdata;
        o_resp_data_sc_ok = r_resp_data_sc_ok;
        o_resp_data_thrd_id = r_resp_data_thrd_id;
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_resp_data_valid <= 1'b0;
            r_resp_data_rdata <= '0;
            r_resp_data_sc_ok <= 1'b0;
            r_resp_data_thrd_id <= '0;
        end else if (data_resp_capture) begin
            r_resp_data_valid <= 1'b1;
            if (data_rob_head_target == DATA_TARGET_MMIO) begin
                r_resp_data_rdata <= i_mmio_resp_rdata;
                r_resp_data_sc_ok <= i_mmio_resp_sc_ok;
                r_resp_data_thrd_id <= i_mmio_resp_thrd_id;
            end else begin
                r_resp_data_rdata <= r_mem_resp_data_rdata[data_rob_head_target[1:0]];
                r_resp_data_sc_ok <= r_mem_resp_data_sc_ok[data_rob_head_target[1:0]];
                r_resp_data_thrd_id <= r_mem_resp_data_thrd_id[data_rob_head_target[1:0]];
            end
        end else if (i_resp_data_ready) begin
            r_resp_data_valid <= 1'b0;
        end
    end

    // One-entry elastic response buffers keep the memory/fabric ready path
    // registered at the router boundary.
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < 4; i++) begin
                r_mem_resp_instr_valid[i] <= 1'b0;
                r_mem_resp_data_valid[i]  <= 1'b0;
            end
        end else begin
            for (int i = 0; i < 4; i++) begin
                if (o_mem_resp_instr_ready[i]) begin
                    r_mem_resp_instr_valid[i] <= i_mem_resp_instr_valid[i];
                    if (i_mem_resp_instr_valid[i]) begin
                        r_mem_resp_instr_rdata[i]   <= i_mem_resp_instr_rdata[i];
                        r_mem_resp_instr_thrd_id[i] <= i_mem_resp_instr_thrd_id[i];
                    end
                end
                if (o_mem_resp_data_ready[i]) begin
                    r_mem_resp_data_valid[i] <= i_mem_resp_data_valid[i];
                    if (i_mem_resp_data_valid[i]) begin
                        r_mem_resp_data_rdata[i]   <= i_mem_resp_data_rdata[i];
                        r_mem_resp_data_sc_ok[i]   <= i_mem_resp_data_sc_ok[i];
                        r_mem_resp_data_thrd_id[i] <= i_mem_resp_data_thrd_id[i];
                    end
                end
            end
        end
    end

endmodule
