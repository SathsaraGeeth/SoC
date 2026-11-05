/*
 * Comments:
 * 1. i_req_addr  - the base address of the page,
 *    o_resp_addr - the base address line,
 *    so this module has the responsible for incrementing the addresses of lines within the page.
 * 2. Load page from the backing memory by LINE by LINE. And evict to backing memory by LINE by LINE.
 *    AXI transactions are 64bits.
 * 3. This is currently implemented using AXI but will be changed to different seiral protocol
 *    in the future.
 * 4. Currently, this module does not allow multiple page request at once
 *    TODO: implement it after the serial protocol is in place
 */

`timescale 1ps/1ps
`default_nettype none
import memory_pkg::*;

module page_engine_axi4 (
    input  logic                             i_clk,
    input  logic                             i_rst_n,
    input  logic                             i_req_we,
    input  logic                             i_req_valid,
    input  logic [VIR_ADDR_W-1:0]            i_req_addr,
    input  logic [LINE_W-1:0]                i_req_wdata,
    output logic                             o_req_ready,
    input  logic                             i_resp_ready,
    output logic                             o_resp_valid,
    output logic [VIR_ADDR_W-1:0]            o_resp_addr,
    output logic                             o_resp_we,
    output logic [LINE_W-1:0]                o_resp_wdata,
    output logic                             o_transfer_done,
    /* AXI4-master-hp if */
    output logic [63:0]                      m_axi4_page_awaddr,
    output logic [7:0]                       m_axi4_page_awlen,
    output logic [2:0]                       m_axi4_page_awsize,
    output logic [1:0]                       m_axi4_page_awburst,
    output logic                             m_axi4_page_awlock,
    output logic [3:0]                       m_axi4_page_awcache,
    output logic [2:0]                       m_axi4_page_awprot,
    output logic [3:0]                       m_axi4_page_awqos,
    output logic [3:0]                       m_axi4_page_awregion,
    output logic [5:0]                       m_axi4_page_awid,
    output logic                             m_axi4_page_awvalid,
    input  logic                             m_axi4_page_awready,
    output logic [63:0]                      m_axi4_page_wdata,
    output logic [7:0]                       m_axi4_page_wstrb,
    output logic                             m_axi4_page_wlast,
    output logic                             m_axi4_page_wvalid,
    input  logic                             m_axi4_page_wready,
    input  logic [1:0]                       m_axi4_page_bresp,
    input  logic [5:0]                       m_axi4_page_bid,
    input  logic                             m_axi4_page_bvalid,
    output logic                             m_axi4_page_bready,
    output logic [63:0]                      m_axi4_page_araddr,
    output logic [7:0]                       m_axi4_page_arlen,
    output logic [2:0]                       m_axi4_page_arsize,
    output logic [1:0]                       m_axi4_page_arburst,
    output logic                             m_axi4_page_arlock,
    output logic [3:0]                       m_axi4_page_arcache,
    output logic [2:0]                       m_axi4_page_arprot,
    output logic [3:0]                       m_axi4_page_arqos,
    output logic [3:0]                       m_axi4_page_arregion,
    output logic [5:0]                       m_axi4_page_arid,
    output logic                             m_axi4_page_arvalid,
    input  logic                             m_axi4_page_arready,
    input  logic [63:0]                      m_axi4_page_rdata,
    input  logic [1:0]                       m_axi4_page_rresp,
    input  logic                             m_axi4_page_rlast,
    input  logic [5:0]                       m_axi4_page_rid,
    input  logic                             m_axi4_page_rvalid,
    output logic                             m_axi4_page_rready
);
    // 1. Constants
    localparam int BURST_BEATS = LINE_W/64;
    localparam int BURST_CTR_W = $clog2(BURST_BEATS) + 1;
    localparam int LINE_BYTES = LINE_W / 8;
    localparam int LINES_PER_PAGE = PAGE_SIZE / LINE_BYTES;
    localparam int LINE_IDX_W = (LINES_PER_PAGE > 1) ? $clog2(LINES_PER_PAGE) : 1;

    always_comb begin: constant_sigs
        m_axi4_page_arlen    = 8'(BURST_BEATS - 1);
        m_axi4_page_arsize   = 3'b011;
        m_axi4_page_arburst  = 2'b01;
        m_axi4_page_arlock   = 1'b0;
        m_axi4_page_arcache  = 4'b0000;
        m_axi4_page_arprot   = 3'b100;
        m_axi4_page_arqos    = 4'b0000;
        m_axi4_page_arregion = 4'b0000;
        m_axi4_page_awlen    = 8'(BURST_BEATS - 1);
        m_axi4_page_awsize   = 3'b011;
        m_axi4_page_awburst  = 2'd1;
        m_axi4_page_awlock   = 1'b0;
        m_axi4_page_awcache  = 4'b0;
        m_axi4_page_awprot   = 3'b0;
        m_axi4_page_awqos    = 4'b0;
        m_axi4_page_awregion = 4'b0;
        m_axi4_page_bready   = 1'b1;
        m_axi4_page_wstrb    = 8'hFF;
    end: constant_sigs

    // 2. alloc id + send req
    localparam int AXI_ID_W  = 6;
    
    logic [(1 << AXI_ID_W)-1:0]            r_req_inflight_id_vec;
    logic                                  w_req_id_free;
    logic                                  w_rd_req_buff_ready;
    logic                                  w_wr_req_buff_ready;
    logic [AXI_ID_W-1:0]                   w_req_id;

    assign w_req_id         = w_line_req_addr[AXI_ID_W-1:0];
    assign w_req_id_free    = !r_req_inflight_id_vec[w_req_id[AXI_ID_W-1:0]];
    assign w_line_req_ready = w_req_id_free && (w_line_req_we
                            ? w_wr_req_buff_ready
                            : w_rd_req_buff_ready);

    always @(posedge i_clk or negedge i_rst_n) begin: req_id_record
        if (!i_rst_n) begin
            r_req_inflight_id_vec <= '0;
        end else begin
            if (w_line_req_valid && w_line_req_ready)
                r_req_inflight_id_vec[w_req_id[AXI_ID_W-1:0]]        <= 1'b1;
            if (m_axi4_page_rvalid && m_axi4_page_rready && m_axi4_page_rlast)
                r_req_inflight_id_vec[m_axi4_page_rid[AXI_ID_W-1:0]] <= 1'b0;
            if (m_axi4_page_bvalid && m_axi4_page_bready)
                r_req_inflight_id_vec[m_axi4_page_bid[AXI_ID_W-1:0]] <= 1'b0;
        end
    end: req_id_record

    // 2.1. Read path
    // 2.1.1. alloc id + send raddr
    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (VIR_ADDR_W + AXI_ID_W)
    ) rd_req_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        ({m_axi4_page_araddr, m_axi4_page_arid}),
        .o_deq_ready                        (m_axi4_page_arvalid),
        .i_deq_valid                        (m_axi4_page_arready),
        .i_enq_tail_data                    ({w_line_req_addr, w_req_id}),
        .i_enq_valid                        (w_line_req_valid && !w_line_req_we && w_line_req_ready),
        .o_enq_ready                        (w_rd_req_buff_ready),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );

    // 2.1.2. fill buff
    logic [LINE_W-64-1:0]                   r_rd_resp_rdata_buf;
    logic [BURST_CTR_W-1:0]                 r_rd_resp_burst_ctr;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_rd_resp_rdata_buf <= 0;
            r_rd_resp_burst_ctr <= 0;
        end else begin
            if (m_axi4_page_rvalid && m_axi4_page_rready) begin
                r_rd_resp_rdata_buf[r_rd_resp_burst_ctr * 64 +: 64] <= m_axi4_page_rdata;
                if (m_axi4_page_rlast)
                    r_rd_resp_burst_ctr <= 0;
                else
                    r_rd_resp_burst_ctr <= r_rd_resp_burst_ctr + 1;
            end
        end
    end

    // 2.1.3. dealloc id + send to resp
    logic [LINE_W-1:0]                      w_rd_resp_data;
    logic [AXI_ID_W-1:0]                    w_rd_resp_id;
    logic                                   w_rd_resp_valid;
    logic                                   w_rd_resp_ready;

    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (LINE_W + AXI_ID_W)
    ) rd_resp_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        ({w_rd_resp_data, w_rd_resp_id}),
        .o_deq_ready                        (w_rd_resp_valid),
        .i_deq_valid                        (w_rd_resp_ready),
        .i_enq_tail_data                    ({m_axi4_page_rdata, r_rd_resp_rdata_buf, m_axi4_page_rid}),
        .i_enq_valid                        (m_axi4_page_rlast && m_axi4_page_rvalid),
        .o_enq_ready                        (m_axi4_page_rready),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );

    // 2.2. Write path
    // 2.2.1. alloc id + send waddr
    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (VIR_ADDR_W + AXI_ID_W)
    ) wr_req_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        ({m_axi4_page_awaddr, m_axi4_page_awid}),
        .o_deq_ready                        (m_axi4_page_awvalid),
        .i_deq_valid                        (m_axi4_page_awready),
        .i_enq_tail_data                    ({w_line_req_addr, w_req_id}),
        .i_enq_valid                        (w_line_req_valid && w_line_req_we && w_line_req_ready),
        .o_enq_ready                        (w_wr_req_buff_ready),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );

    // 2.2.2. fill buff
    logic [LINE_W-1:0]                      w_wr_data_head;
    logic                                   w_wr_data_head_valid;
    logic                                   w_wr_data_head_deq;
    logic [LINE_W-1:0]                      r_wr_data_shift;
    logic [BURST_CTR_W-1:0]                 r_wr_burst_ctr;
    logic                                   r_wr_burst_active;

    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (LINE_W)
    ) wr_data_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        (w_wr_data_head),
        .o_deq_ready                        (w_wr_data_head_valid),
        .i_deq_valid                        (w_wr_data_head_deq),
        .i_enq_tail_data                    (w_line_req_wdata),
        .i_enq_valid                        (w_line_req_valid && w_line_req_we && w_line_req_ready),
        .o_enq_ready                        (),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );

    assign w_wr_data_head_deq = w_wr_data_head_valid && !r_wr_burst_active;
    assign m_axi4_page_wvalid = r_wr_burst_active;
    assign m_axi4_page_wdata  = r_wr_data_shift[63:0];
    assign m_axi4_page_wlast  = (r_wr_burst_ctr == BURST_CTR_W'(BURST_BEATS - 1));

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_wr_data_shift   <= '0;
            r_wr_burst_ctr    <= '0;
            r_wr_burst_active <= 1'b0;
        end else begin
            if (!r_wr_burst_active && w_wr_data_head_valid) begin
                r_wr_data_shift       <= w_wr_data_head;
                r_wr_burst_ctr        <= '0;
                r_wr_burst_active     <= 1'b1;
            end else if (r_wr_burst_active && m_axi4_page_wready) begin
                r_wr_data_shift       <= r_wr_data_shift >> 64;
                if (m_axi4_page_wlast) begin
                    r_wr_burst_active <= 1'b0;
                    r_wr_burst_ctr    <= '0;
                end else begin
                    r_wr_burst_ctr    <= r_wr_burst_ctr + 1'b1;
                end
            end
        end
    end

    // 2.2.3. dealloc id + send to resp
    logic [AXI_ID_W-1:0]                    w_wr_resp_id;
    logic                                   w_wr_resp_valid;
    logic                                   w_wr_resp_ready;

    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (AXI_ID_W)
    ) wr_resp_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        (w_wr_resp_id),
        .o_deq_ready                        (w_wr_resp_valid),
        .i_deq_valid                        (w_wr_resp_ready),
        .i_enq_tail_data                    (m_axi4_page_bid[AXI_ID_W-1:0]),
        .i_enq_valid                        (m_axi4_page_bvalid),
        .o_enq_ready                        (),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );
    
    // 3. resp out
    circular_buffer #(
        .DEPTH                              (NUM_PAGES),
        .WIDTH                              (1 + VIR_ADDR_W + LINE_W)
    ) resp_out_buffer (
        .i_clk                              (i_clk),
        .i_rst_n                            (i_rst_n),
        .o_head_data                        ({w_line_resp_we, w_line_resp_addr, w_line_resp_wdata}),
        .o_deq_ready                        (w_line_resp_valid),
        .i_deq_valid                        (w_line_resp_ready && w_line_resp_valid),
        .i_enq_tail_data                    ({~w_rd_resp_valid,
                                              w_rd_resp_valid ? VIR_ADDR_W'(w_rd_resp_id) : VIR_ADDR_W'(w_wr_resp_id),
                                              w_rd_resp_valid ? w_rd_resp_data            : {(LINE_W){1'b0}}}),
        .i_enq_valid                        (w_rd_resp_valid || w_wr_resp_valid),
        .o_enq_ready                        (),
        .o_full                             (),
        .o_empty                            (),
        .o_level                            (),
        .i_clr_n                            (1'b1)
    );

    assign w_rd_resp_ready = w_rd_resp_valid;
    assign w_wr_resp_ready = !w_rd_resp_valid && w_wr_resp_valid;



    /* page sequencer---   */
    logic                             w_line_req_we;
    logic                             w_line_req_valid;
    logic [VIR_ADDR_W-1:0]            w_line_req_addr;
    logic [LINE_W-1:0]                w_line_req_wdata;
    logic                             w_line_req_ready;
    logic                             w_line_resp_ready;
    logic                             w_line_resp_valid;
    logic [VIR_ADDR_W-1:0]            w_line_resp_addr;
    logic                             w_line_resp_we;
    logic [LINE_W-1:0]                w_line_resp_wdata;

    typedef enum logic [2:0] {
        PAGE_IDLE,
        PAGE_LOAD_ISSUE,
        PAGE_LOAD_RESP,
        PAGE_EVICT_SRAM_REQ,
        PAGE_EVICT_SRAM_DATA,
        PAGE_EVICT_AXI_RESP
    } page_state_t;

    page_state_t           r_page_state;
    logic [VIR_ADDR_W-1:0] r_backing_page;
    logic [PPN_W-1:0]      r_sram_ppn;
    logic [LINE_IDX_W-1:0] r_line_idx;

    logic [VIR_ADDR_W-1:0] w_line_offset;
    logic [VIR_ADDR_W-1:0] w_backing_byte_addr;
    logic [VIR_ADDR_W-1:0] w_sram_byte_addr;
    logic                  w_last_line;

    assign w_line_offset       = VIR_ADDR_W'(r_line_idx) * VIR_ADDR_W'(LINE_BYTES);
    assign w_backing_byte_addr = (r_backing_page << PAGE_BYTES_W) + w_line_offset;
    assign w_sram_byte_addr    = (VIR_ADDR_W'(r_sram_ppn) << PAGE_BYTES_W) + w_line_offset;
    assign w_last_line         = (r_line_idx == LINE_IDX_W'(LINES_PER_PAGE - 1));

    always_comb begin
        o_req_ready       = 1'b0;
        o_resp_valid      = 1'b0;
        o_resp_addr       = w_sram_byte_addr;
        o_resp_we         = 1'b0;
        o_resp_wdata      = w_line_resp_wdata;
        o_transfer_done   = 1'b0;

        w_line_req_we     = 1'b0;
        w_line_req_valid  = 1'b0;
        w_line_req_addr   = w_backing_byte_addr;
        w_line_req_wdata  = i_req_wdata;
        w_line_resp_ready = 1'b0;

        case (r_page_state)
            PAGE_IDLE: o_req_ready = 1'b1;
            PAGE_LOAD_ISSUE: w_line_req_valid = 1'b1;
            PAGE_LOAD_RESP: begin
                o_resp_valid      = w_line_resp_valid;
                o_resp_we         = 1'b1;
                w_line_resp_ready = i_resp_ready;
                o_transfer_done   = w_line_resp_valid && i_resp_ready && w_last_line;
            end
            PAGE_EVICT_SRAM_REQ: begin
                o_resp_valid = 1'b1;
                o_resp_we    = 1'b0;
            end
            PAGE_EVICT_SRAM_DATA: begin
                o_req_ready      = w_line_req_ready;
                w_line_req_we    = 1'b1;
                w_line_req_valid = i_req_valid;
            end
            PAGE_EVICT_AXI_RESP: begin
                w_line_resp_ready = 1'b1;
                o_transfer_done   = w_line_resp_valid && w_last_line;
            end
            default: begin end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_page_state   <= PAGE_IDLE;
            r_backing_page <= '0;
            r_sram_ppn     <= '0;
            r_line_idx     <= '0;
        end else begin
            case (r_page_state)
                PAGE_IDLE: if (i_req_valid && o_req_ready) begin
                    r_backing_page <= i_req_addr;
                    r_sram_ppn     <= i_req_wdata[PPN_W-1:0];
                    r_line_idx     <= '0;
                    r_page_state   <= i_req_we ? PAGE_EVICT_SRAM_REQ : PAGE_LOAD_ISSUE;
                end
                PAGE_LOAD_ISSUE: if (w_line_req_ready)
                    r_page_state <= PAGE_LOAD_RESP;
                PAGE_LOAD_RESP: if (w_line_resp_valid && i_resp_ready) begin
                    if (w_last_line)
                        r_page_state <= PAGE_IDLE;
                    else begin
                        r_line_idx   <= r_line_idx + 1'b1;
                        r_page_state <= PAGE_LOAD_ISSUE;
                    end
                end
                PAGE_EVICT_SRAM_REQ: if (i_resp_ready)
                    r_page_state <= PAGE_EVICT_SRAM_DATA;
                PAGE_EVICT_SRAM_DATA: if (i_req_valid && w_line_req_ready)
                    r_page_state <= PAGE_EVICT_AXI_RESP;
                PAGE_EVICT_AXI_RESP: if (w_line_resp_valid) begin
                    if (w_last_line)
                        r_page_state <= PAGE_IDLE;
                    else begin
                        r_line_idx   <= r_line_idx + 1'b1;
                        r_page_state <= PAGE_EVICT_SRAM_REQ;
                    end
                end
                default: r_page_state <= PAGE_IDLE;
            endcase
        end
    end
    /*  ---page sequencer */

endmodule: page_engine_axi4

`default_nettype wire
