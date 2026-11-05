#include <stdint.h>
#include <nom.h>
#include <regs.h>


static volatile uint32_t nom_transfer_generation = 0;
static volatile uint32_t nom_transfer_src_region = 0;
static volatile uint32_t nom_transfer_dst_mask = 0;
static volatile uint32_t nom_transfer_byte_offset = 0;
static volatile uint32_t nom_transfer_start_word = 0;
static volatile uint32_t nom_transfer_word_count = 0;
static volatile uint32_t nom_transfer_done[THREADS_IN_CLUSTER];
static volatile uint32_t nom_transfer_workers_enabled = 1;

static inline void nom_transfer_fence(void) {
    __asm__ volatile ("fence rw, rw" ::: "memory");
}

/*
 * NOM transfer algorithms general idea:
 * - Transfers are throughput oriented data movement, not mailbox messages(which are latency oriented).
 * - A source memory region should fan out through every cluster that can touch
 *   the source and one or more destination regions.
 * - Worker threads should copy strided lanes. When one helper can write several
 *   destinations, it should load each source word once into a register and then
 *   store that word to all assigned destination regions.
 * - Large transfers should be chunk pipelined so downstream regions can start
 *   forwarding a chunk before the whole blob finishes.
 */


/*
 * is manhattan distance 1?
 */
bool nom_transfer_can_touch(uint32_t tid, uint32_t region_id) {
    uint64_t base;
    uint32_t addr_row;
    uint32_t addr_col;
    uint32_t tid_row;
    uint32_t tid_col;
    uint32_t row_delta;
    uint32_t col_delta;

    if (region_id >= NUM_REGIONS) {
        return false;
    }

    base = get_region_base(region_id);
    addr_row = ADDR_ROW(base);
    addr_col = ADDR_COL(base);
    tid_row = THREAD_ROW(tid);
    tid_col = THREAD_COL(tid);
    row_delta = (addr_row > tid_row) ? (addr_row - tid_row) : (tid_row - addr_row);
    col_delta = (addr_col > tid_col) ? (addr_col - tid_col) : (tid_col - addr_col);

    return (row_delta + col_delta) == 1u;
}

/*
 * can tid touch src & dst? + src != dst
 */
bool nom_transfer_can_copy(uint32_t tid, uint32_t src_region, uint32_t dst_region) {
    if (src_region >= NUM_REGIONS || dst_region >= NUM_REGIONS || src_region == dst_region) {
        return false;
    }

    return nom_transfer_can_touch(tid, src_region) && nom_transfer_can_touch(tid, dst_region);
}

/*
 * the simt copy primitive. a thread would call this.
 * from the src it copy the word into a register then paste to everywhere it can touch. (ofc. masked)
 * masking becuse some memory region can be touched by many - so stop duplication.
 */
void nom_transfer_copy_lane(uint32_t src_region, uint32_t dst_mask, uint32_t byte_offset,
                            uint32_t start_word, uint32_t word_count, uint32_t lane, uint32_t stride) {
    volatile const uint32_t *src;
    volatile uint32_t *dst[4];
    uint32_t dst_count = 0;
    uint32_t end_word;

    if (src_region >= NUM_REGIONS || stride == 0u || lane >= stride) {
        return;
    }

    src = (volatile const uint32_t *)(get_region_base(src_region) | byte_offset);
    end_word = start_word + word_count;

    for (uint32_t dst_region = 0; dst_region < NUM_REGIONS && dst_count < 4u; dst_region++) {
        if ((dst_mask & (1u << dst_region)) == 0u || dst_region == src_region) {
            continue;
        }

        dst[dst_count++] = (volatile uint32_t *)(get_region_base(dst_region) | byte_offset);
    }

    /* unrolled for performance and made branch free in the hot loop */
    if (dst_count == 1u) {
        uint32_t word_index = start_word + lane;
        uint32_t stride_x4 = stride * 4;
        for (; word_index + stride * 3 < end_word; word_index += stride_x4) {
            uint32_t w0 = src[word_index];
            uint32_t w1 = src[word_index + stride];
            uint32_t w2 = src[word_index + stride * 2];
            uint32_t w3 = src[word_index + stride * 3];
            dst[0][word_index] = w0;
            dst[0][word_index + stride] = w1;
            dst[0][word_index + stride * 2] = w2;
            dst[0][word_index + stride * 3] = w3;
        }
        for (; word_index < end_word; word_index += stride) {
            dst[0][word_index] = src[word_index];
        }
    } else if (dst_count == 2u) {
        uint32_t word_index = start_word + lane;
        uint32_t stride_x4 = stride * 4;
        for (; word_index + stride * 3 < end_word; word_index += stride_x4) {
            uint32_t w0 = src[word_index];
            uint32_t w1 = src[word_index + stride];
            uint32_t w2 = src[word_index + stride * 2];
            uint32_t w3 = src[word_index + stride * 3];
            dst[0][word_index] = w0;
            dst[1][word_index] = w0;
            dst[0][word_index + stride] = w1;
            dst[1][word_index + stride] = w1;
            dst[0][word_index + stride * 2] = w2;
            dst[1][word_index + stride * 2] = w2;
            dst[0][word_index + stride * 3] = w3;
            dst[1][word_index + stride * 3] = w3;
        }
        for (; word_index < end_word; word_index += stride) {
            uint32_t w = src[word_index];
            dst[0][word_index] = w;
            dst[1][word_index] = w;
        }
    } else if (dst_count == 3u) {
        uint32_t word_index = start_word + lane;
        uint32_t stride_x4 = stride * 4;
        for (; word_index + stride * 3 < end_word; word_index += stride_x4) {
            uint32_t w0 = src[word_index];
            uint32_t w1 = src[word_index + stride];
            uint32_t w2 = src[word_index + stride * 2];
            uint32_t w3 = src[word_index + stride * 3];
            dst[0][word_index] = w0;
            dst[1][word_index] = w0;
            dst[2][word_index] = w0;
            dst[0][word_index + stride] = w1;
            dst[1][word_index + stride] = w1;
            dst[2][word_index + stride] = w1;
            dst[0][word_index + stride * 2] = w2;
            dst[1][word_index + stride * 2] = w2;
            dst[2][word_index + stride * 2] = w2;
            dst[0][word_index + stride * 3] = w3;
            dst[1][word_index + stride * 3] = w3;
            dst[2][word_index + stride * 3] = w3;
        }
        for (; word_index < end_word; word_index += stride) {
            uint32_t w = src[word_index];
            dst[0][word_index] = w;
            dst[1][word_index] = w;
            dst[2][word_index] = w;
        }
    } else if (dst_count == 4u) {
        uint32_t word_index = start_word + lane;
        uint32_t stride_x4 = stride * 4;
        for (; word_index + stride * 3 < end_word; word_index += stride_x4) {
            uint32_t w0 = src[word_index];
            uint32_t w1 = src[word_index + stride];
            uint32_t w2 = src[word_index + stride * 2];
            uint32_t w3 = src[word_index + stride * 3];
            dst[0][word_index] = w0;
            dst[1][word_index] = w0;
            dst[2][word_index] = w0;
            dst[3][word_index] = w0;
            dst[0][word_index + stride] = w1;
            dst[1][word_index + stride] = w1;
            dst[2][word_index + stride] = w1;
            dst[3][word_index + stride] = w1;
            dst[0][word_index + stride * 2] = w2;
            dst[1][word_index + stride * 2] = w2;
            dst[2][word_index + stride * 2] = w2;
            dst[3][word_index + stride * 2] = w2;
            dst[0][word_index + stride * 3] = w3;
            dst[1][word_index + stride * 3] = w3;
            dst[2][word_index + stride * 3] = w3;
            dst[3][word_index + stride * 3] = w3;
        }
        for (; word_index < end_word; word_index += stride) {
            uint32_t w = src[word_index];
            dst[0][word_index] = w;
            dst[1][word_index] = w;
            dst[2][word_index] = w;
            dst[3][word_index] = w;
        }
    }
}

void nom_transfer_copy_all(uint32_t src_region, uint32_t dst_mask, uint32_t byte_offset,
                            uint32_t start_word, uint32_t word_count) {
    nom_transfer_copy_lane(src_region, dst_mask, byte_offset, start_word, word_count, 0u, 1u);
    nom_transfer_fence();
}

void nom_transfer_worker_loop(uint32_t tid) {
    uint32_t local_tid = THREAD_OFFSET(tid);
    uint32_t seen_generation = 0;

    if (local_tid == 0u) {
        return;
    }

    for (;;) {
        uint32_t generation = nom_transfer_generation;

        if (nom_transfer_workers_enabled == 0u) {
            return;
        }

        if (generation == 0u || generation == seen_generation) {
            wfi();
            continue;
        }

        nom_transfer_copy_lane(nom_transfer_src_region, nom_transfer_dst_mask,
            nom_transfer_byte_offset, nom_transfer_start_word, nom_transfer_word_count,
            local_tid, THREADS_IN_CLUSTER);
        nom_transfer_fence();
        nom_transfer_done[local_tid] = generation;
        nom_transfer_fence();
        seen_generation = generation;
        ipi_trigger_target(0u);
    }
}

void nom_transfer_stop_workers(void) {
    nom_transfer_workers_enabled = 0;
    nom_transfer_fence();
    ipi_trigger_secondary(0u);
}
