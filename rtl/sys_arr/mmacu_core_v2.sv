/*
 * Usage: dense mode
 *
 * This block computes:
 *
 *     C = A^T × B
 *
 * M and K are fixed RTL parameters:
 *
 *     M = array tile width and height
 *     K = maximum number of tiles in every dense mode dimension
 *
 * Define the workload dimensions in tiles:
 *
 *     A_TILES = rows of C divided by M
 *     R_TILES = shared reduction dimension divided by M
 *     B_TILES = columns of C divided by M
 *
 * Required limits:
 *
 *     1 <= A_TILES <= K
 *     1 <= R_TILES <= K
 *     1 <= B_TILES <= K
 *
 * Matrix dimensions:
 *
 *     A^T has A_TILES*M rows and R_TILES*M columns
 *     B   has R_TILES*M rows and B_TILES*M columns
 *     C   has A_TILES*M rows and B_TILES*M columns
 *
 * Tile notation:
 *
 *     A[r][i] is an M×M tile of the stored A matrix
 *     B[r][j] is an M×M tile of B
 *     C[i][j] is an M×M tile of C
 *
 *     r is the reduction-tile index: 0 through R_TILES-1
 *     i is the A-column and C-row tile index: 0 through A_TILES-1
 *     j is the B-column and C-column tile index: 0 through B_TILES-1
 *
 * Mathematical operation:
 *
 *     C[i][j] = sum over r of A[r][i] × B[r][j]
 *
 * Configuration:
 *
 *     i_dense = 1
 *     i_k2    = B_TILES
 *
 * Output tile order:
 *
 *     for each i from 0 through A_TILES-1:
 *         for each q from 0 through B_TILES-1:
 *             j = (q - i) modulo B_TILES
 *             produce C[i][j]
 *
 * Reduction order for every C[i][j]:
 *
 *     A[0][i] with B[0][j]
 *     A[1][i] with B[1][j]
 *     ...
 *     A[R_TILES-1][i] with B[R_TILES-1][j]
 *
 * Each reduction tile consists of M vector beats.
 *
 * Control signals:
 *
 *     i_start:
 *         Assert on the first beat of every C[i][j] tile.
 *
 *     i_last:
 *         Assert on the first beat of the final reduction tile,
 *         A[R_TILES-1][i] with B[R_TILES-1][j].
 *
 *     i_end:
 *         Assert only on the final beat of the final output tile:
 *
 *             i == A_TILES-1
 *             q == B_TILES-1
 *             r == R_TILES-1
 *             beat == M-1
 *
 * Input protocol:
 *
 *     Hold each externally requested operand and its control signals stable
 *     until its valid and ready handshake completes.
 *
 *     Send A only when o_a_ready is high.
 *     Send B only when o_b_ready is high.
 *
 *     Operand reuse is selected internally by mmacu_core_v2. The driver does
 *     not explicitly manage the reuse FIFOs and must not send an operand when
 *     its corresponding ready signal is low.
 */

/*
 * Comments:
 * 1. v1 vs v2
 *  - v1 is more flexible, and can achieve the behavior of v2 with the
 *    external logic. And v1 is more suitable for large dimension.
 *  - v2 is written targeting for tiled to smaller size (e.g. 8*8 or 16*16),
 *    simpler, low bandwidth usage, and emphasis data reuse in the module itself.
 *    (in contrast v1 relies on external regifile/fifo for the same goal).
 * - v2 does not supercedes v1.
 * - v2 does not support dynamic dim configs.
 * - just like v1 v2 also dont do adressing, and rely on external driver
 * - also naturally do ATB - to get AB view AT as A using memory system
 * - both array them self trade +MxM in space for no stall between streams
 * 
 *      C00 = A00·B00 + A10·B10 + A20·B20
 *      C01 = A00·B01 + A10·B11 + A20·B21
 *      C02 = A00·B02 + A10·B12 + A20·B22
 * 
 *      C10 = A01·B00 + A11·B10 + A21·B20
 *      C11 = A01·B01 + A11·B11 + A21·B21
 *      C12 = A01·B02 + A11·B12 + A21·B22
 * 
 *      C20 = A02·B00 + A12·B10 + A22·B20
 *      C21 = A02·B01 + A12·B11 + A22·B21
 *      C22 = A02·B02 + A12·B12 + A22·B22
 *
 *      3*3 x 3*4      
 *
 *      C00 = A00·B00 + A10·B01 + A20·B02
 *      C01 = A00·B01 + A10·B11 + A20·B21
 *      C02 = A00·B02 + A10·B12 + A20·B22
 *      C03 = A00·B03 + A10·B13 + A20·B23
 * 
 *      C10 = A01·B00 + A11·B01 + A21·B02
 *      C11 = A01·B01 + A11·B11 + A21·B21
 *      C12 = A01·B02 + A11·B12 + A21·B22
 *      C13 = A01·B03 + A11·B13 + A21·B23

 *
 * 2. A stream is queued.  For a non-square full multiply, let
 *    A be (K1*M)x(K*M) and B be (K*M)x(K2*M), yielding C of (K1*M)x(K2*M).
 *    A's FIFO is sized to hold K2 matrices (MxM).
 * 3. If not dense then A/B directly to array, and start, last, and break handled by external logic
 * 4. If dense only start needed to be handled by external logic
 *      - if (fifo.h < M*K2 | age=0) -> in a  -> fifo.t + array
 *        else                       -> fifo.h-> fifo.t + array; age++
 *        when age reach K2-1 (= buff full signal) drop them start for the next sequence.
 *        when age reaches K2-2 pulse last
 *        age is a counter can go to K2-1 from 0
 *      - so need to feed A00, A10, A20, A01, A11, A21, A02, A12, A22 when asks
 *        simply row by row (no complex addressing). (the external driver should handle this).
 * 5. Space complexity of the fifo.A: K2xMxM
 *      - if we were to keep the B as well ^ it would be K1xK2xMxM + K2xMxM. not practical.
 *      - since it depends on the M^2 of the it is quite small for small M, also it
 *        depends on K2. thus the claim, v2 is designed for tiled mmul with smaller arrays.
 *      - note: K1xK2xMxM = matrix size. tho even if full caching impractical it is smaller than
 *              two matrices.
 *      - this vs conventional weight stationary: this get rid of the traffic of partial sums
 *        && get the free partial sum reduction.
 * 6. for a little cost of +K2xMxM (so totaling 2xK2xMxM) we get more reuse for B as well.
 *      -  2xK2xMxM <<< K1xK2xMxM; for M<K1
 * 7. rctr = 0 (rctr a counter can go to (K1-1)MxM from 0); rctr++ for any b handshake
 *    if rctr<<$clog2(M*M) > (K1-2) -> in b  -> fifo.t + array
 *    if rctr<<$clog2(M*M) > (K1-1) -> fifo.h-> array
 *    rctr=K1xMxM-1 triggers a break; should start flushing
 *    - so need to be in the order B00, B10, B20, B01, B11, B21, B02, B12, B22
 *                                 B00, B10, B20, B01, B11, B21
 *                                 B02, B12, B22, B01, B11, B21
 *      the order(the second idx: B01<-*) is 0->1->2->0->1->2->1. (the external driver should handle this)
 *    - see we saves K1(K2-1)MxM in bandwidth
 * 8. The dense mode is for dense GEMM while the manual one is good fore flexible sparse GEMM
 * 9. Tiling algorithm for dense DEMM:
 *    - C[i][j] = sum(k) A[k][i] * B[k][j]; each product uses K M beat blocks,
 *      with i in [0,K1) and j in [0,K2).
 *    - For each A tile i, issue B tile j in a right rotation: j = (q-i) mod K2.
 *      Feed A[0][i]..A[K-1][i] and B[0][j]..B[K-1][j] for each C[i][j].
 *
 * 10. We design hardware for the symmetric case K=K1=K2.
 */

`timescale 1ns/1ps
`default_nettype none

import  sys_cnfg_pkg::*;

module mmacu_core_v2 #(
    parameter mac_static_t MAC_STATIC_TYPE = MAC_T
) (
    input  logic                                    i_clk,
    input  logic                                    i_rst_n,
    input  logic                                    i_dense,
    input  mac_t                                    i_mac_type,
    input  logic [$clog2(K+1)-1:0]                  i_k2,
    input  logic                                    i_start,    /* pulse */
    input  logic                                    i_last,     /* pulse */
    input  logic                                    i_end,      /* pulse */
    input  logic [M*WIDTH_AB-1:0]                   i_a,
    input  logic [M*WIDTH_AB-1:0]                   i_b,
    input  logic                                    i_a_valid,
    input  logic                                    i_b_valid,
    output logic                                    o_a_ready,
    output logic                                    o_b_ready,
    output logic [M*WIDTH_CD-1:0]                   o_d,
    output logic                                    o_d_valid,
    input  logic                                    i_d_ready
);
    /* Control--- */
    logic [M*WIDTH_AB-1:0]      w_src_a;
    logic [M*WIDTH_AB-1:0]      w_src_b;
    logic                       w_src_a_valid;
    logic                       w_src_b_valid;
    logic                       w_gstall_n;
    logic                       w_ab_ready;    
    logic                       w_ab_en;
    logic                       w_start;
    logic                       w_last;
    logic                       w_clr_n;
    logic                       w_tile_slot_available;
    logic                       w_tile_retired;
    logic [1:0]                 r_tiles_inflight;
    logic [$clog2(K+1)-1:0]     r_k2;
    logic [$clog2(K+1)-1:0]     r_ageA;
    logic                       r_reuse_a_active;
    logic                       r_recycle_a_active;
    logic                       w_dense_reuse_a;
    logic                       w_reuse_a_available;
    logic                       w_recycle_a;
    logic                       r_reuse_b_active;
    logic                       r_enqueue_b_active;
    logic                       w_dense_reuse_b;
    logic                       w_reuse_b_available;
    logic                       w_recycle_b;
    logic                       w_native_ab_ready;
    logic [$clog2(M)-1:0]       r_b_post_last_rows;
    logic [$clog2(K+1)-1:0]     r_ageB;
    logic                       w_b_tile_advance;
    logic                       w_dense_mode;
    logic [M-1:0]               r_done_row;

    assign w_dense_mode          = r_flushing ? r_flush_dense : i_dense;
    assign w_tile_slot_available = !i_start || (r_tiles_inflight < 2);
    assign w_dense_reuse_a       = w_dense_mode && (i_start ? (r_ageA != '0) : r_reuse_a_active);
    assign w_reuse_a_available   = !w_reuse_a_empty;
    assign w_src_a               = w_dense_reuse_a ? w_reuse_a_head : i_a;
    assign w_src_a_valid         = w_dense_reuse_a ? w_reuse_a_available : i_a_valid;
    assign w_dense_reuse_b       = w_dense_mode && (i_start ? ((r_ageA == '0) && !w_reuse_b_empty) : r_reuse_b_active);
    assign w_reuse_b_available   = !w_reuse_b_empty;
    assign w_src_b               = w_dense_reuse_b ? w_reuse_b_head : i_b;
    assign w_src_b_valid         = w_dense_reuse_b ? w_reuse_b_available : i_b_valid;
    assign w_recycle_a           = !w_dense_mode || (i_start ? (!w_dense_reuse_a || (r_ageA < r_k2 - 1'b1)) : r_recycle_a_active);
    assign w_recycle_b           = !w_dense_mode || (i_start ? (r_ageA == r_k2 - 1'b1) : r_enqueue_b_active);
    assign w_native_ab_ready     = w_ab_ready && w_src_a_valid && w_src_b_valid;
    assign o_a_ready             = w_dense_mode ? (w_ab_ready && !w_dense_reuse_a && w_src_b_valid) : w_native_ab_ready;
    assign o_b_ready             = w_dense_mode ? (w_ab_ready && !w_dense_reuse_b && w_src_a_valid) : w_native_ab_ready;

    always_comb begin
        w_gstall_n     = !(o_d_valid && !i_d_ready);
        w_ab_ready     = w_gstall_n && !r_flushing && w_tile_slot_available;
        w_ab_en        = w_gstall_n && (r_flushing || (w_tile_slot_available && w_src_a_valid && w_src_b_valid));
        w_start        = (!r_flushing && i_start)  || (r_flushing && (r_flush_ctr == '0));
        w_last         = (!r_flushing && i_last)   || (r_flushing && (r_flush_ctr == '0));
        w_tile_retired = r_done_row[M-1] && (!o_d_valid || i_d_ready);
    end



    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !w_dense_mode ||
            (r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))) begin
            r_tiles_inflight <= '0;
        end else begin
            case ({(w_ab_en && w_last), w_tile_retired})
                2'b10: r_tiles_inflight <= r_tiles_inflight + 1'b1;
                2'b01: if (r_tiles_inflight != '0)
                           r_tiles_inflight <= r_tiles_inflight - 1'b1;
                default: r_tiles_inflight <= r_tiles_inflight;
            endcase
        end
    end

    /*  ---Control */

    /* Mac type---  */
    mac_t r_mac_type;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_mac_type    <= (MAC_STATIC_TYPE == MACFP8_STATIC) ? MACFP8 : MAC20I;
        end else if (i_b_valid && o_b_ready) begin
            r_mac_type    <= i_mac_type;
        end
    end
    /*  ---Mac type */

    /* Alife-- */
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_k2   <= '0;
            r_ageA <= '0;
            r_reuse_a_active <= 1'b0;
            r_recycle_a_active <= 1'b0;
        end else if (!w_dense_mode) begin
            r_k2   <= '0;
            r_ageA <= '0;
            r_reuse_a_active <= 1'b0;
            r_recycle_a_active <= 1'b0;
        end else begin
            r_k2 <= i_k2;

            if (w_ab_en && i_start) begin
                r_reuse_a_active <= (r_ageA != '0);
                r_recycle_a_active <= !w_dense_reuse_a || (r_ageA < r_k2 - 1'b1);
            end

            if (w_ab_en && i_last && !r_flushing) begin
                if ((r_k2 > 1) && (r_ageA == r_k2 - 1'b1)) begin
                    r_ageA <= '0;
                end else begin
                    r_ageA <= r_ageA + 1'b1;
                end
            end
        end
    end
    /*  ---Alife */

    /* Blife-- */
    assign w_b_tile_advance = w_ab_en && !r_flushing && (r_b_post_last_rows == 1);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !w_dense_mode ||
            (r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))) begin
            r_b_post_last_rows <= '0;
            r_ageB <= '0;
            r_reuse_b_active <= 1'b0;
            r_enqueue_b_active <= 1'b0;
        end else if (w_ab_en && !r_flushing) begin
            if (i_start) begin
                r_reuse_b_active <= (r_ageA == '0) && !w_reuse_b_empty;
                r_enqueue_b_active <= (r_ageA == r_k2 - 1'b1);
            end
            if (i_last) begin
                r_b_post_last_rows <= $clog2(M)'(M-1);
            end else if (r_b_post_last_rows != '0) begin
                r_b_post_last_rows <= r_b_post_last_rows - 1'b1;
            end
            if (w_b_tile_advance) begin
                r_ageB <= r_ageB + 1'b1;
            end
        end
    end
    /*  ---Blife */


    /* Unloading---  */
    logic [M-1:0]          w_done_row;
    logic [M*WIDTH_CD-1:0] w_unload_data;

    always_comb begin
        w_done_row = '0;
        w_unload_data = '0;
        for (int m = 0; m < M; m++) begin
            w_done_row[m] = wn_done[m][M-1] && wn_valid_d[m][M-1];
            if (r_done_row[m]) begin
                for (int j = 0; j < M; j++) begin
                    w_unload_data[j*WIDTH_CD +: WIDTH_CD] |= wn_d[m][j];
                end
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_done_row <= '0;
            o_d <= '0;
            o_d_valid <= 1'b0;
        end else begin
            if (w_gstall_n) begin
                r_done_row <= w_done_row;
            end
            if (r_flush_output_done || (r_flushing && w_gstall_n && (r_flush_ctr == FLUSH_W'(mac_output_cycle(r_mac_type, r_flush_k2))) && o_d_valid && i_d_ready)) begin
                o_d_valid <= 1'b0;
            end else if (!o_d_valid || i_d_ready) begin
                o_d_valid <= |r_done_row && !r_flush_output_done;
                if (|r_done_row) begin
                    o_d <= w_unload_data;
                end
            end
        end
    end
    /*  ---Unloading */

    /* Flushing---  */
    logic                   r_flushing;
    logic [FLUSH_W-1:0]     r_flush_ctr;
    logic                   r_flush_output_done;
    logic [FLUSH_W-1:0]     r_flush_cycles;
    logic [$clog2(K+1)-1:0] r_flush_k2;
    logic                   r_flush_dense;

    assign w_clr_n = !(r_flushing && w_gstall_n && (r_flush_ctr == (r_flush_cycles-1'b1)));

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_flushing     <= 1'b0;
            r_flush_ctr    <= '0;
            r_flush_cycles <= 0;
            r_flush_k2     <= '0;
            r_flush_dense  <= 1'b0;
        end else begin
            r_flush_cycles <= FLUSH_W'(mac_flush(r_mac_type));
            if (w_ab_en && !r_flushing && i_end) begin
                r_flush_k2    <= i_k2;
                r_flush_dense <= i_dense;
            end
            if (r_flushing && w_gstall_n) begin
                if (r_flush_ctr == (r_flush_cycles-1'b1)) begin
                    r_flushing <= 1'b0;
                    r_flush_ctr <= '0;
                end else begin
                    r_flush_ctr <= r_flush_ctr + 1'b1;
                end
            end else if (!r_flushing && w_ab_en && i_end) begin
                r_flushing <= 1'b1;
                r_flush_ctr <= '0;
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_flush_output_done <= 1'b0;
        end else if (w_ab_en && !r_flushing && i_start) begin
            r_flush_output_done <= 1'b0;
        end else if (r_flushing && w_gstall_n && (r_flush_ctr == FLUSH_W'(mac_output_cycle(r_mac_type, r_flush_k2)))) begin
            r_flush_output_done <= 1'b1;
        end
    end

    /*  ---Flushing */


    /* Array---  */
    logic [M*WIDTH_AB-1:0]        w_a;
    logic [M*WIDTH_AB-1:0]        w_b;
    logic                         wn_valid           [M][M];
    logic                         wn_valid_d         [M][M];
    logic                         wn_reuse_capture   [M][M];
    logic                         wn_reuse_b_capture [M][M];
    logic                         wn_clr_n           [M][M];
    logic                         wn_start           [M][M];
    logic                         wn_last            [M][M];
    logic                         wn_done            [M][M];
    logic                         wn_fp8_done        [M][M];
    logic                         wn_int8_done       [M][M];
    logic [WIDTH_AB-1:0]          wn_a               [M][M];
    logic [WIDTH_AB-1:0]          wn_b               [M][M];
    logic [WIDTH_CD-1:0]          wn_d               [M][M];
    logic [WIDTH_CD-1:0]          wn_fp8_d           [M][M];
    logic [WIDTH_CD-1:0]          wn_int8_d          [M][M];
    logic [WIDTH_AB-1:0]          wn_a_dly           [M];
    logic                         wn_start_dly       [M];
    logic                         wn_last_dly        [M];
    logic [WIDTH_AB-1:0]          wn_b_dly           [M];

    assign w_a = r_flushing ? '0 : w_src_a;
    assign w_b = r_flushing ? '0 : w_src_b;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int x = 0; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_valid[x][y]           <= 1'b0;
                    wn_valid_d[x][y]         <= 1'b0;
                    wn_clr_n[x][y]           <= 1'b0;
                end
            end
        end else if (w_gstall_n) begin
            for (int x = 0; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_valid_d[x][y] <= wn_valid[x][y];
                end
            end
            wn_valid[0][0]           <= w_ab_en;
            wn_clr_n[0][0] <= w_clr_n;
            for (int y = 1; y < M; y++) begin
                wn_valid[0][y]           <= wn_valid[0][y-1];
                wn_clr_n[0][y]           <= wn_clr_n[0][y-1];
            end
            for (int x = 1; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_valid[x][y]           <= wn_valid[x-1][y];
                    wn_clr_n[x][y]           <= wn_clr_n[x-1][y];
                end
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !w_dense_mode ||
            (r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))) begin
            for (int x = 0; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_reuse_capture[x][y]   <= 1'b0;
                    wn_reuse_b_capture[x][y] <= 1'b0;
                end
            end
        end else if (w_gstall_n) begin
            wn_reuse_capture[0][0]   <= w_ab_en && !r_flushing && w_recycle_a;
            wn_reuse_b_capture[0][0] <= w_ab_en && !r_flushing && w_recycle_b;
            for (int y = 1; y < M; y++) begin
                wn_reuse_capture[0][y]   <= wn_reuse_capture[0][y-1];
                wn_reuse_b_capture[0][y] <= wn_reuse_b_capture[0][y-1];
            end
            for (int x = 1; x < M; x++) begin
                for (int y = 0; y < M; y++) begin
                    wn_reuse_capture[x][y]   <= wn_reuse_capture[x-1][y];
                    wn_reuse_b_capture[x][y] <= wn_reuse_b_capture[x-1][y];
                end
            end
        end
    end
    
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : ROW
            for (j = 0; j < M; j++) begin : COL
                if ((MAC_STATIC_TYPE == MAC20I_STATIC) || (MAC_STATIC_TYPE == MACFP8INT8_STATIC)) begin
                    mac20i_v2 #(WIDTH_AB, WIDTH_CD, M) u_mac (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid_d[i][j] && w_gstall_n && (r_mac_type == MAC20I)),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_start   (wn_start[i][j]),
                        .i_last    (wn_last[i][j]),
                        .i_a       (wn_a[i][j]),
                        .i_b       (wn_b[i][j]),
                        .o_done    (wn_int8_done[i][j]),
                        .o_d       (wn_int8_d[i][j])
                    );
                end 
                if ((MAC_STATIC_TYPE == MACFP8_STATIC) || (MAC_STATIC_TYPE == MACFP8INT8_STATIC)) begin
                    mac_fp8_fp8_fp8_61_v2 u_mac (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid_d[i][j] && w_gstall_n && (r_mac_type == MACFP8)),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_start   (wn_start[i][j]),
                        .i_last    (wn_last[i][j]),
                        .i_a       (wn_a[i][j]),
                        .i_b       (wn_b[i][j]),
                        .o_done    (wn_fp8_done[i][j]),
                        .o_d       (wn_fp8_d[i][j])
                    );
                end
                assign wn_done[i][j] = (r_mac_type == MACFP8) ? wn_fp8_done[i][j] : wn_int8_done[i][j];
                assign wn_d[i][j]    = (r_mac_type == MACFP8) ? wn_fp8_d[i][j]    : wn_int8_d[i][j];

                if (j == 0) begin : GEN_DELAY_A
                    delayed_pipe #(.WIDTH (WIDTH_AB+1+1), .DEPTH (i+1)) u_delay_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (w_gstall_n),
                        .i_clr_n   (w_clr_n),
                        .i_in      ({w_a[i*WIDTH_AB +: WIDTH_AB], w_start, w_last}),
                        .o_out     ({wn_a_dly[i], wn_start_dly[i], wn_last_dly[i]})
                    );
                    register #(WIDTH_AB+1+1) u_shift_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j] && w_gstall_n),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    ({wn_a_dly[i], wn_start_dly[i], wn_last_dly[i]}),
                        .o_data    ({wn_a[i][j], wn_start[i][j], wn_last[i][j]})
                    );
                end else begin : GEN_SHIFT_A
                    register #(WIDTH_AB+1+1) u_shift_a (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j] && w_gstall_n),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    ({wn_a[i][j-1], wn_start[i][j-1], wn_last[i][j-1]}),
                        .o_data    ({wn_a[i][j], wn_start[i][j], wn_last[i][j]})
                    );
                end
                if (i == 0) begin : GEN_DELAY_B
                    delayed_pipe #(.WIDTH (WIDTH_AB), .DEPTH (j+1)) u_delay_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (w_gstall_n),
                        .i_clr_n   (w_clr_n),
                        .i_in      (w_b[j*WIDTH_AB +: WIDTH_AB]),
                        .o_out     (wn_b_dly[j])
                    );
                    register #(WIDTH_AB) u_shift_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j] && w_gstall_n),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    (wn_b_dly[j]),
                        .o_data    (wn_b[i][j])
                    );
                end else begin : GEN_SHIFT_B
                    register #(WIDTH_AB) u_shift_b (
                        .i_clk     (i_clk),
                        .i_rst_n   (i_rst_n),
                        .i_en      (wn_valid[i][j] && w_gstall_n),
                        .i_clr_n   (wn_clr_n[i][j]),
                        .i_data    (wn_b[i-1][j]),
                        .o_data    (wn_b[i][j])
                    );
                end
            end
        end
    endgenerate
    /*  ---Array */


    /* Reuse---  */
    localparam int REUSE_BUFF_D = K*M;

    logic [M*WIDTH_AB-1:0]             w_reuse_a_fall;
    logic [M*WIDTH_AB-1:0]             w_reuse_b_fall;
    logic [M*WIDTH_AB-1:0]             w_reuse_a_head;
    logic [M*WIDTH_AB-1:0]             w_reuse_b_head;
    logic                              w_reuse_a_deq_ready;
    logic                              w_reuse_b_deq_ready;
    logic                              w_reuse_a_full;
    logic                              w_reuse_b_full;
    logic                              w_reuse_a_empty;
    logic                              w_reuse_b_empty;
    logic [$clog2(REUSE_BUFF_D+1)-1:0] w_reuse_a_level;
    logic [$clog2(REUSE_BUFF_D+1)-1:0] w_reuse_b_level;
    logic                              w_reuse_enq_valid;
    logic                              r_reuse_enq_valid;
    logic                              w_reuse_b_enq_valid;
    logic                              r_reuse_b_enq_valid;
    logic                              w_reuse_flush_marker;
    logic                              r_reuse_tail_flushing;

    assign w_reuse_flush_marker = wn_start[M-1][M-1] && wn_last[M-1][M-1];
    assign w_reuse_enq_valid    = r_reuse_enq_valid && !r_reuse_tail_flushing && !w_reuse_flush_marker;
    assign w_reuse_b_enq_valid  = r_reuse_b_enq_valid && !r_reuse_tail_flushing && !w_reuse_flush_marker;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_reuse_enq_valid     <= 1'b0;
            r_reuse_b_enq_valid   <= 1'b0;
            r_reuse_tail_flushing <= 1'b0;
        end else if (!w_dense_mode || (r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))) begin
            r_reuse_enq_valid     <= 1'b0;
            r_reuse_b_enq_valid   <= 1'b0;
            r_reuse_tail_flushing <= 1'b0;
        end else begin
            if (!r_flushing) begin
                r_reuse_tail_flushing <= 1'b0;
            end else if (w_reuse_flush_marker) begin
                r_reuse_tail_flushing <= 1'b1;
            end

            if (w_reuse_flush_marker || r_reuse_tail_flushing) begin
                r_reuse_enq_valid   <= 1'b0;
                r_reuse_b_enq_valid <= 1'b0;
            end else begin
                r_reuse_enq_valid   <= wn_reuse_capture[M-1][M-1];
                r_reuse_b_enq_valid <= wn_reuse_b_capture[M-1][M-1];
            end
        end
    end

    circular_buffer #(
        .DEPTH (REUSE_BUFF_D),
        .WIDTH (M*WIDTH_AB)
    ) u_reuse_a (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_clr_n         (w_dense_mode &&
                          !(r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))),
        .i_enq_tail_data (w_reuse_a_fall),
        .i_enq_valid     (w_reuse_enq_valid),
        .o_enq_ready     (),
        .o_empty         (w_reuse_a_empty),
        .i_deq_valid     (w_ab_en && !r_flushing && w_dense_reuse_a),
        .o_deq_ready     (w_reuse_a_deq_ready),
        .o_head_data     (w_reuse_a_head),
        .o_level         (w_reuse_a_level),
        .o_full          (w_reuse_a_full)
    );

    circular_buffer #(
        .DEPTH (REUSE_BUFF_D),
        .WIDTH (M*WIDTH_AB)
    ) u_reuse_b (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_clr_n         (w_dense_mode &&
                          !(r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))),
        .i_enq_tail_data (w_reuse_b_fall),
        .i_enq_valid     (w_reuse_b_enq_valid),
        .o_enq_ready     (),
        .o_empty         (w_reuse_b_empty),
        .i_deq_valid     (w_ab_en && !r_flushing && w_dense_reuse_b),
        .o_deq_ready     (w_reuse_b_deq_ready),
        .o_head_data     (w_reuse_b_head),
        .o_level         (w_reuse_b_level),
        .o_full          (w_reuse_b_full)
    );

    genvar r;
    generate
        for (r = 0; r < M; r++) begin : REUSE_FALL
            delayed_pipe #(
                .WIDTH   (WIDTH_AB),
                .DEPTH   (M-1-r)
            ) u_align_a  (
                .i_clk   (i_clk),
                .i_rst_n (i_rst_n),
                .i_en    (1'b1),
                .i_clr_n (w_dense_mode && !(r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))),
                .i_in    (wn_a[r][M-1]),
                .o_out   (w_reuse_a_fall[r*WIDTH_AB +: WIDTH_AB])
            );
            delayed_pipe #(
                .WIDTH   (WIDTH_AB),
                .DEPTH   (M-1-r)
            ) u_align_b  (
                .i_clk   (i_clk),
                .i_rst_n (i_rst_n),
                .i_en    (1'b1),
                .i_clr_n (w_dense_mode && !(r_flushing && w_gstall_n && (r_flush_ctr == r_flush_cycles - 1'b1))),
                .i_in    (wn_b[M-1][r]),
                .o_out   (w_reuse_b_fall[r*WIDTH_AB +: WIDTH_AB])
            );
        end
    endgenerate
    /*  ---Reuse */

endmodule: mmacu_core_v2
