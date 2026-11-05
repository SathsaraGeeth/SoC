/*
 * Comments:
 * 1. Low order interleaved.
 * 2. Pipeline
 *     S1: logical ports - va2pa_table lookup & bank arbitration ->  bank queues
 *     S2: bank queue -> bank
 *     S3: bank -> logical ports
 * 3. mem_va2pa_table is 1 cycle read and write (i.e. sram based not ff based)
 * 4. r_active_vtid is a small register arr.
 * 5. banks corresponging to empty bank queus are clk gated (latch based)
 */


`timescale 1ns/1ps
`default_nettype none
import memory_pkg::*;

module memory #(
    parameter int REGION_ID = 0
) (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic                            i_req_we            [NUM_RW_PORTS-1:0],
    input  logic [THRD_W-1:0]               i_req_thrd          [NUM_RW_PORTS-1:0],
    input  logic                            i_req_is_lr         [NUM_RW_PORTS-1:0],
    input  logic                            i_req_is_sc         [NUM_RW_PORTS-1:0],
    input  logic [VIR_ADDR_W-1:0]           i_req_addr          [NUM_RW_PORTS-1:0],
    input  logic [XLEN/8-1:0]               i_req_wstrb         [NUM_RW_PORTS-1:0],
    input  logic [XLEN-1:0]                 i_req_wdata         [NUM_RW_PORTS-1:0],
    input  logic                            i_req_valid         [NUM_RW_PORTS-1:0],
    input  logic [1:0]                      i_req_priv          [NUM_RW_PORTS-1:0],
    output logic                            o_req_ready         [NUM_RW_PORTS-1:0],
    output logic [THRD_W-1:0]               o_resp_thrd         [NUM_RW_PORTS-1:0],
    output logic                            o_resp_sc_succ      [NUM_RW_PORTS-1:0],
    output logic [XLEN-1:0]                 o_resp_rdata        [NUM_RW_PORTS-1:0],
    output logic                            o_resp_valid        [NUM_RW_PORTS-1:0],
    input  logic                            i_resp_ready        [NUM_RW_PORTS-1:0],
    input  logic                            i_page_msg_valid    [NUM_RW_PORTS-1:0],
    output logic                            o_page_msg_ready    [NUM_RW_PORTS-1:0],
    input  logic [PAGE_MSG_W-1:0]           i_page_msg          [NUM_RW_PORTS-1:0],
    input  logic                            i_page_msg_ready    [NUM_RW_PORTS-1:0],
    output logic                            o_page_msg_valid    [NUM_RW_PORTS-1:0],
    output logic [PAGE_MSG_W-1:0]           o_page_msg          [NUM_RW_PORTS-1:0],
    /* page engine if */
    output logic                            o_page_req_we,
    output logic                            o_page_req_valid,
    input  logic                            i_page_req_ready,
    output logic [VIR_ADDR_W-1:0]           o_page_req_addr,
    output logic [LINE_W-1:0]               o_page_req_wdata,
    input  logic [VIR_ADDR_W-1:0]           i_page_resp_addr,
    input  logic                            i_page_resp_we,
    input  logic [LINE_W-1:0]               i_page_resp_wdata,
    input  logic                            i_page_resp_valid,
    output logic                            o_page_resp_ready,
    input  logic                            i_page_transfer_done,
    output logic                            o_page_completion_pending,
    output logic [THRD_W-1:0]               o_page_completion_thrd
);
    logic                                   w_mem_clk           [NUM_BANKS-1:0];
    logic                                   w_mem_req_valid     [NUM_BANKS-1:0];
    logic                                   w_mem_req_ready     [NUM_BANKS-1:0];
    logic                                   w_mem_resp_expected [NUM_BANKS-1:0];
    logic                                   w_mem_resp_valid    [NUM_BANKS-1:0];
    logic                                   w_mem_resp_ready    [NUM_BANKS-1:0];
    logic                                   w_mem_lr            [NUM_BANKS-1:0];
    logic                                   w_mem_sc            [NUM_BANKS-1:0];
    logic [BANK_ADDR_W-1:0]                 w_mem_raddr         [NUM_BANKS-1:0];
    logic [BANK_ADDR_W-1:0]                 w_mem_waddr         [NUM_BANKS-1:0];
    logic [BANK_WORD_W/8-1:0]               w_mem_wstrb         [NUM_BANKS-1:0];
    logic [XLEN-1:0]                        w_mem_wdata         [NUM_BANKS-1:0];
    logic                                   w_mem_we            [NUM_BANKS-1:0];
    logic                                   w_mem_sc_succ       [NUM_BANKS-1:0];
    logic [XLEN-1:0]                        w_mem_rdata         [NUM_BANKS-1:0];

    logic                                   w_rbuf_clk          [NUM_BANKS-1:0];
    logic                                   w_rbuf_rst_n        [NUM_BANKS-1:0];
    bank_req_t                              w_rbuf_head_data    [NUM_BANKS-1:0];
    logic                                   w_rbuf_deq_ready    [NUM_BANKS-1:0];
    logic                                   w_rbuf_deq_valid    [NUM_BANKS-1:0];
    logic                                   w_rbuf_enq_valid    [NUM_BANKS-1:0];
    bank_req_t                              w_rbuf_enq_addr     [NUM_BANKS-1:0];
    logic                                   w_rbuf_enq_ready    [NUM_BANKS-1:0];
    logic [$clog2(REQ_BUFF_DEPTH+1)-1:0]    w_rbuf_level        [NUM_BANKS-1:0];


    va2pa_t                                 mem_va2pa_table     [NUM_PAGES-1:0] [NUM_RW_PORTS-1:0];  // per port table synced

    logic                                   r_page_read_pending;
    logic [THRD_W-1:0]                      r_page_req_thrd;

    generate
        for (genvar i = 0; i < NUM_BANKS; i++) begin
            sram_bank    #(.BANK_IDX(i))
            sram_bank_u (
                .i_clk           (w_mem_clk          [i]),
                .i_rst_n         (i_rst_n),
                .i_req_valid     (w_mem_req_valid    [i]),
                .i_resp_expected (w_mem_resp_expected[i]),
                .o_req_ready     (w_mem_req_ready    [i]),
                .o_resp_valid    (w_mem_resp_valid   [i]),
                .i_resp_ready    (w_mem_resp_ready   [i]),
                .i_req_port      (w_rbuf_head_data   [i].port),
                .i_req_thrd      (w_rbuf_head_data   [i].thrd),
                .i_raddr         (w_mem_raddr        [i]),
                .i_waddr         (w_mem_waddr        [i]),
                .i_lr            (w_mem_lr           [i]),
                .i_sc            (w_mem_sc           [i]),
                .i_wstrb         (w_mem_wstrb        [i]),
                .i_wdata         (w_mem_wdata        [i]),
                .i_we            (w_mem_we           [i]),
                .o_rdata         (w_mem_rdata        [i]),
                .o_resp_port     (r_bank_resp_port   [i]),
                .o_resp_thrd     (r_bank_resp_thrd   [i]),
                .o_sc_succ       (w_mem_sc_succ      [i])
            );
            circular_buffer #(.DEPTH(REQ_BUFF_DEPTH), .WIDTH($bits(bank_req_t)))
            req_buff_u (
                .i_clk           (w_rbuf_clk      [i]),
                .i_rst_n         (w_rbuf_rst_n    [i]),
                .o_head_data     (w_rbuf_head_data[i]),
                .o_deq_ready     (w_rbuf_deq_ready[i]),
                .i_deq_valid     (w_rbuf_deq_valid[i]),
                .i_enq_tail_data (w_rbuf_enq_addr [i]),
                .i_enq_valid     (w_rbuf_enq_valid[i]),
                .o_enq_ready     (w_rbuf_enq_ready[i]),
                .o_full          (),
                .o_empty         (),
                .o_level         (w_rbuf_level[i]),
                .i_clr_n         (1'b1)
            );
        end
    endgenerate
    /* ----**/


    /*
     * When a page response comming route it though the same path
     * that port request takes. At the end of burst can update the
     * page tables. Though the invalidation immediate is done at
     * the page request is initiated
     */

    

    /* 1 & 2A. Port Request Translating & Bank Queue Enqueuing---  */
    logic [VTID_W-1:0]                      r_active_vtid       [topology_pkg::THREADS_PER_CLUSTER-1:0];
    req_t                                   s0_req              [NUM_RW_PORTS-1:0];
    logic                                   s0_valid            [NUM_RW_PORTS-1:0];
    logic [VTID_W-1:0]                      s0_vtid             [NUM_RW_PORTS-1:0];
    va2pa_t                                 s0_va2pa            [NUM_RW_PORTS-1:0];
    logic [VPN_W-1:0]                       s0_vpn              [NUM_RW_PORTS-1:0];
    logic [BANK_ADDR_W-1:0]                 s0_baddr            [NUM_RW_PORTS-1:0];
    logic [$clog2(NUM_BANKS)-1:0]           s0_bank             [NUM_RW_PORTS-1:0];
    logic                                   s0_hit              [NUM_RW_PORTS-1:0];
    logic [PORT_IDX_W-1:0]                  s0_grant_port       [NUM_BANKS-1:0];
    logic                                   s0_grant_valid      [NUM_BANKS-1:0];
    logic                                   s0_page_resp_grant;
    logic                                   s0_enq_stage_ready;
    logic                                   s0_port_ready       [NUM_RW_PORTS-1:0];
    bank_req_t                              s0_page_bank_req    [NUM_BANKS-1:0];
    bank_req_t                              s0_port_bank_req    [NUM_RW_PORTS-1:0];
    logic                                   s1_enq_valid        [NUM_BANKS-1:0];
    bank_req_t                              s1_enq_req          [NUM_BANKS-1:0];

    always_comb begin
        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            logic [VIR_ADDR_W-1:0] pa;
            logic                  mode_ok;

            s0_vpn[p]   = s0_req[p].addr[VIR_ADDR_W-1:$clog2(PAGE_SIZE)];
            mode_ok     = (s0_req[p].priv != isa_pkg::PRIV_MODE_U) || s0_va2pa[p].user_acc;
            s0_hit[p]   = s0_va2pa[p].valid && (s0_va2pa[p].vpn  == s0_vpn[p]) &&
                          ((s0_va2pa[p].vtid == s0_vtid[p]) || (s0_va2pa[p].vtid == {VTID_W{1'b1}})) &&
                          mode_ok && (!s0_req[p].we || s0_va2pa[p].writable || s0_req[p].priv != isa_pkg::PRIV_MODE_U);
            pa          = {{(VIR_ADDR_W - PPN_W - $clog2(PAGE_SIZE)){1'b0}},
                          s0_va2pa[p].ppn, s0_req[p].addr[$clog2(PAGE_SIZE)-1:0]};
            s0_bank[p]  = $clog2(NUM_BANKS)'((pa >> $clog2(XLEN / 8)) % NUM_BANKS);
            s0_baddr[p] = BANK_ADDR_W'      ((pa >> $clog2(XLEN / 8)) / NUM_BANKS);
        end

        for (int b = 0; b < NUM_BANKS; b++) begin
            s0_page_bank_req[b] = bank_req_t'{
                baddr:        BANK_ADDR_W'((i_page_resp_addr >> $clog2(XLEN / 8)) / NUM_BANKS),
                port:         '0,
                is_page_resp: 1'b1,
                is_lr:        1'b0,
                is_sc:        1'b0,
                we:           i_page_resp_we,
                wstrb:        {(XLEN/8){1'b1}},
                wdata:        i_page_resp_wdata[b*XLEN +: XLEN],
                thrd:         '0
            };
        end

        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            s0_port_bank_req[p] = bank_req_t'{
                baddr:        s0_baddr[p],
                port:         p[PORT_IDX_W-1:0],
                is_page_resp: 1'b0,
                is_lr:        s0_req[p].is_lr,
                is_sc:        s0_req[p].is_sc,
                we:           s0_req[p].we,
                wstrb:        s0_req[p].wstrb,
                wdata:        s0_req[p].wdata,
                thrd:         s0_req[p].thrd
            };
        end

        for (int b = 0; b < NUM_BANKS; b++) begin
            s0_grant_port [b] = '0;
            s0_grant_valid[b] = 1'b0;
        end
        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            s0_port_ready   [p] = 1'b0;
            o_req_ready     [p] = !s0_valid[p];
            o_page_msg_valid[p] = 1'b0;
            o_page_msg      [p] = '0;
        end

        s0_enq_stage_ready = 1'b1;
        for (int b = 0; b < NUM_BANKS; b++) begin
            s0_enq_stage_ready &= !s1_enq_valid[b] || w_rbuf_enq_ready[b];
        end

        s0_page_resp_grant = i_page_resp_valid && s0_enq_stage_ready;
        o_page_resp_ready  = s0_enq_stage_ready;

        if (!i_page_resp_valid && s0_enq_stage_ready) begin
            for (int b = 0; b < NUM_BANKS; b++) begin
                for (int p = 0; p < NUM_RW_PORTS; p++) begin
                    if (s0_valid[p] && s0_hit[p] &&
                        (s0_bank[p] == $clog2(NUM_BANKS)'(b))) begin
                        s0_grant_port [b] = p[PORT_IDX_W-1:0];
                        s0_grant_valid[b] = 1'b1;
                        break;
                    end
                end
            end
        end

        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            if (s0_valid[p]) begin
                if (i_page_resp_valid) begin
                    s0_port_ready[p] = 1'b0;
                end else if (s0_hit[p]) begin
                    if (s0_grant_valid[s0_bank[p]] &&
                        (s0_grant_port[s0_bank[p]] == p[PORT_IDX_W-1:0])) begin
                        s0_port_ready[p] = 1'b1;
                        o_req_ready  [p] = 1'b1;
                    end
                end else begin
                    s0_port_ready[p] = i_page_msg_ready[p];
                    o_page_msg_valid[p] = 1'b1;
                    o_page_msg      [p] = page_fault_msg_t'{
                        padding:  '0,
                        thrd_id:  s0_req[p].thrd,
                        vpn:      s0_vpn[p],
                        msg_type: PAGE_MSG_FAULT
                    };
                end
            end
        end

        for (int b = 0; b < NUM_BANKS; b++) begin
            w_rbuf_enq_valid[b] = s1_enq_valid[b];
            w_rbuf_enq_addr [b] = s1_enq_req  [b];
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                s0_valid[p] <= 1'b0;
                s0_req  [p] <= '0;
                s0_vtid [p] <= '0;
                s0_va2pa[p] <= '0;
            end
        end else begin
            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                logic [$clog2(NUM_PAGES)-1:0] safe_vpn;
                if (o_req_ready[p]) begin
                    s0_valid[p] <= i_req_valid[p];
                    safe_vpn    = $clog2(NUM_PAGES)'((i_req_addr[p][VIR_ADDR_W-1:$clog2(PAGE_SIZE)]) % NUM_PAGES);
                    s0_va2pa[p] <= mem_va2pa_table[safe_vpn][p];

                    if (i_req_valid[p]) begin
                        s0_req[p].addr  <= i_req_addr[p];
                        s0_req[p].is_lr <= i_req_is_lr[p];
                        s0_req[p].is_sc <= i_req_is_sc[p];
                        s0_req[p].we    <= i_req_we[p];
                        s0_req[p].wstrb <= i_req_wstrb[p];
                        s0_req[p].wdata <= i_req_wdata[p];
                        s0_req[p].thrd  <= i_req_thrd[p];
                        s0_req[p].priv  <= i_req_priv[p];
                        s0_vtid[p]      <= r_active_vtid[i_req_thrd[p]];
                    end
                end else if (s0_port_ready[p]) begin
                    s0_valid[p] <= 1'b0;
                end
            end
        end
    end


    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int b = 0; b < NUM_BANKS; b++) begin
                s1_enq_valid[b] <= 1'b0;
                s1_enq_req  [b] <= '0;
            end
        end else begin
            for (int b = 0; b < NUM_BANKS; b++) begin
                if (s1_enq_valid[b] && w_rbuf_enq_ready[b]) begin
                    s1_enq_valid[b] <= 1'b0;
                end

                if (s0_page_resp_grant) begin
                    s1_enq_valid[b] <= 1'b1;
                    s1_enq_req  [b] <= s0_page_bank_req[b];
                end else if (s0_grant_valid[b]) begin
                    s1_enq_valid[b] <= 1'b1;
                    s1_enq_req  [b] <= s0_port_bank_req[s0_grant_port[b]];
                end
            end
        end
    end


    /* wildcard - XLEN'1 (all ones) */
    /* 2B. Page Request Generating (&page table invalidation &setting the owner vtid, wildcarded at init)---  */
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_page_req_valid <= 1'b0;
            r_page_req_thrd <= '0;
            o_page_req_we    <= 1'b0;
            o_page_req_addr  <= '0;
            o_page_req_wdata <= '0;
            r_page_read_pending <= 1'b0;
            o_page_completion_pending <= 1'b0;
            o_page_completion_thrd    <= '0;

            for (int t = 0; t < topology_pkg::THREADS_PER_CLUSTER; t++) begin
                r_active_vtid[t] <= '0;
            end

            for (int i = 0; i < NUM_PAGES; i++) begin
                for (int p = 0; p < NUM_RW_PORTS; p++) begin
                    mem_va2pa_table[i][p] <= va2pa_t'{
                        perm:     isa_pkg::PRIV_MODE_M,
                        user_acc: 1'b0,
                        writable: 1'b1,
                        rrpv:     '0,
                        valid:    1'b1,
                        vtid:     {VTID_W{1'b1}},
                        ppn:      PPN_W'(i),
                        vpn:      VPN_W'(i)
                    };
                end
            end
        end else begin
            o_page_req_valid <= o_page_req_valid && !i_page_req_ready;
            if (i_page_transfer_done) begin
                o_page_completion_pending <= 1'b1;
            end else if (o_page_req_valid && i_page_req_ready) begin
                o_page_completion_pending <= 1'b0;
                o_page_completion_thrd    <= r_page_req_thrd;
            end

            if (r_page_read_pending) begin
                for (int b = 0; b < NUM_BANKS; b++) begin
                    o_page_req_wdata[b*XLEN +: XLEN] <= w_mem_rdata[b];
                end
                r_page_read_pending <= 1'b0;
            end
            if (w_mem_req_valid[0] && w_rbuf_head_data[0].is_page_resp &&
                !w_rbuf_head_data[0].we) begin
                r_page_read_pending <= 1'b1;
            end

            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                if (i_page_msg_valid[p]) begin
                    generic_page_msg_t gen_msg;
                    gen_msg = i_page_msg[p];

                    if (gen_msg.msg_type == PAGE_MSG_PAGE_LOAD) begin
                        page_transfer_msg_t load_msg;
                        load_msg = i_page_msg[p];
                        if (!o_page_req_valid || i_page_req_ready) begin
                            o_page_req_valid <= 1'b1;
                            r_page_req_thrd  <= load_msg.thrd_id;
                            o_page_req_we    <= 1'b0;
                            o_page_req_addr  <= VIR_ADDR_W'(load_msg.axi_addr);
                            o_page_req_wdata <= LINE_W'(load_msg.ppn);
                        end
                    end else if (gen_msg.msg_type == PAGE_MSG_PAGE_EVICT) begin
                        page_transfer_msg_t evict_msg;
                        evict_msg = i_page_msg[p];
                        if (!o_page_req_valid || i_page_req_ready) begin
                            o_page_req_valid <= 1'b1;
                            r_page_req_thrd  <= evict_msg.thrd_id;
                            o_page_req_we    <= 1'b1;
                            o_page_req_addr  <= VIR_ADDR_W'(evict_msg.axi_addr);
                            o_page_req_wdata <= LINE_W'(evict_msg.ppn);
                        end
                    end else if (gen_msg.msg_type == PAGE_MSG_TLB_UPDATE) begin
                        tlb_update_msg_t tlb_msg;
                        va2pa_t          upd_entry;
                        tlb_msg = i_page_msg[p];
                        upd_entry = va2pa_t'{
                            perm:     isa_pkg::PRIV_MODE_M,
                            user_acc: tlb_msg.user_acc,
                            writable: tlb_msg.writable,
                            rrpv:     '0,
                            valid:    1'b1,
                            vtid:     tlb_msg.vtid,
                            ppn:      tlb_msg.ppn,
                            vpn:      tlb_msg.vpn
                        };
                        for (int q = 0; q < NUM_RW_PORTS; q++) begin
                            mem_va2pa_table[tlb_msg.vpn[$clog2(NUM_PAGES)-1:0]][q] <= upd_entry;
                        end
                    end else if (gen_msg.msg_type == PAGE_MSG_VTID_UPDATE) begin
                        vtid_update_msg_t vtid_msg;
                        vtid_msg = i_page_msg[p];
                        r_active_vtid[vtid_msg.thrd_id] <= vtid_msg.vtid;
                    end
                end
            end
        end
    end
    
    always_comb begin
        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            o_page_msg_ready[p] = 1'b1;
        end
    end
    /*  ---Page Request Generating */



    /* 3. Bank Queue Draining & bank clk gating---  */
    logic   w_mem_clk_en_latch  [NUM_BANKS-1:0];
    logic   w_mem_clk_en        [NUM_BANKS-1:0];

    always_latch begin
        for (int b = 0; b < NUM_BANKS; b++) begin
            if (!i_clk) begin
                w_mem_clk_en_latch[b] = w_mem_clk_en[b];
            end
        end
    end

    always_comb begin
        for (int b = 0; b < NUM_BANKS; b++) begin
            w_rbuf_clk          [b] = i_clk;
            w_rbuf_rst_n        [b] = i_rst_n;
            w_mem_req_valid     [b] = w_rbuf_deq_ready[b] && w_mem_req_ready[b];
            w_rbuf_deq_valid    [b] = w_mem_req_valid[b];
            w_mem_resp_expected [b] = !w_rbuf_head_data[b].is_page_resp;
            w_mem_clk_en        [b] = !i_rst_n || w_rbuf_deq_ready[b] || w_mem_resp_valid[b];
            w_mem_clk           [b] = i_clk && w_mem_clk_en_latch[b];
            w_mem_lr            [b] = w_rbuf_head_data[b].is_lr && w_mem_req_valid[b];
            w_mem_sc            [b] = w_rbuf_head_data[b].is_sc && w_mem_req_valid[b];
            w_mem_raddr         [b] = w_rbuf_head_data[b].baddr;
            w_mem_waddr         [b] = w_rbuf_head_data[b].baddr;
            w_mem_wstrb         [b] = w_rbuf_head_data[b].wstrb;
            w_mem_wdata         [b] = w_rbuf_head_data[b].wdata;
            w_mem_we            [b] = w_rbuf_head_data[b].we && w_mem_req_valid[b];
        end
    end
    /*  ---Bank Queue Draining */

    
    /* 4. Bank Response to Port---  */
    logic [$clog2(NUM_BANKS)-1:0]   r_last_served_bank  [NUM_RW_PORTS-1:0];
    logic [$clog2(NUM_BANKS)-1:0]   w_next_served_bank  [NUM_RW_PORTS-1:0];
    logic                           r_chosen_valid      [NUM_BANKS-1:0];
    logic                           w_bank_chosen       [NUM_BANKS-1:0];
    logic                           w_port_locked       [NUM_RW_PORTS-1:0];
    logic [PORT_IDX_W-1:0]          r_bank_resp_port    [NUM_BANKS-1:0];
    logic [THRD_W-1:0]              r_bank_resp_thrd    [NUM_BANKS-1:0];
    logic                           r_bank_resp_sc_succ [NUM_BANKS-1:0];

    always_comb begin
        for (int b = 0; b < NUM_BANKS; b++) begin
            w_bank_chosen    [b] = 1'b0;
            w_mem_resp_ready [b] = 1'b0;
        end

        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            o_resp_valid      [p] = 1'b0;
            o_resp_rdata      [p] = '0;
            o_resp_thrd       [p] = '0;
            o_resp_sc_succ    [p] = 1'b0;
            w_port_locked     [p] = 1'b0;
            w_next_served_bank[p] = r_last_served_bank[p];
        end

        for (int b = 0; b < NUM_BANKS; b++) begin
            if (r_chosen_valid[b]) begin
                w_port_locked   [r_bank_resp_port[b]] =
                    !w_mem_resp_valid[b] || !i_resp_ready[r_bank_resp_port[b]];
                o_resp_valid    [r_bank_resp_port[b]] = w_mem_resp_valid[b] && r_chosen_valid[b];
                o_resp_rdata    [r_bank_resp_port[b]] = w_mem_rdata[b];
                o_resp_thrd     [r_bank_resp_port[b]] = r_bank_resp_thrd[b];
                o_resp_sc_succ  [r_bank_resp_port[b]] = r_bank_resp_sc_succ[b];
                w_mem_resp_ready[b]                   = i_resp_ready[r_bank_resp_port[b]];
                w_bank_chosen   [b]                   = 1'b1;
            end
        end

        for (int p = 0; p < NUM_RW_PORTS; p++) begin
            logic found;
            logic [$clog2(NUM_BANKS)-1:0] bidx;
            found = 1'b0;
            bidx  = '0;
            if (i_resp_ready[p] && !w_port_locked[p]) begin
                for (int off = 0; off < NUM_BANKS; off++) begin
                    bidx = $clog2(NUM_BANKS)'((32'(r_last_served_bank[p]) + off) % NUM_BANKS);
                    if (!found && !w_bank_chosen[bidx] && w_mem_resp_valid[bidx] && (r_bank_resp_port[bidx] == p[PORT_IDX_W-1:0])) begin
                        found                 = 1'b1;
                        w_next_served_bank[p] = bidx;
                        w_bank_chosen[bidx]   = 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                r_last_served_bank[p] <= '0;
            end
            for (int b = 0; b < NUM_BANKS; b++) begin
                r_chosen_valid     [b] <= 1'b0;
                r_bank_resp_sc_succ[b] <= 1'b0;
            end
        end else begin
            for (int b = 0; b < NUM_BANKS; b++) begin
                if (w_mem_resp_ready[b]) begin
                    r_chosen_valid[b]    <= 1'b0;
                end
                if (w_rbuf_deq_valid[b]) begin
                    r_bank_resp_sc_succ[b] <= w_mem_sc_succ[b];
                end
                if (w_bank_chosen[b] && !r_chosen_valid[b]) begin
                    r_chosen_valid[b] <= 1'b1;
                end
            end
            for (int p = 0; p < NUM_RW_PORTS; p++) begin
                r_last_served_bank[p] <= w_next_served_bank[p];
            end
        end
    end
    /*  ---Bank Response to Port */
endmodule: memory

`default_nettype wire
