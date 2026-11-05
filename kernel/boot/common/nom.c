#include <stdint.h>
#include <nom.h>
#include <regs.h>

#define NOM_TRANSFER_MESSAGE_ID 0u
#define NOM_TRANSFER_REQ_PAYLOAD 1u
#define NOM_TRANSFER_ACK_PAYLOAD 2u
#define NOM_TRANSFER_REQ_NOACK_PAYLOAD 3u
#define NOM_TRANSFER_PAYLOAD(op, mask, offset, words) \
    ((((uint64_t)((op) & 0xffu)) << 56) | (((uint64_t)((mask) & 0xffu)) << 48) | \
     (((uint64_t)((offset) & 0x00ffffffu)) << 24) | ((uint64_t)((words) & 0x00ffffffu)))
#define NOM_TRANSFER_PAYLOAD_OP(payload) ((uint32_t)(((payload) >> 56) & 0xffu))
#define NOM_TRANSFER_PAYLOAD_MASK(payload) ((uint32_t)(((payload) >> 48) & 0xffu))
#define NOM_TRANSFER_PAYLOAD_OFFSET(payload) ((uint32_t)(((payload) >> 24) & 0x00ffffffu))
#define NOM_TRANSFER_PAYLOAD_WORDS(payload) ((uint32_t)((payload) & 0x00ffffffu))

static uint32_t nom_region_from_xy(uint32_t x, uint32_t y) {
    if (x >= 4u || y >= 4u || (((x + y) & 1u) == 0u)) {
        return NUM_REGIONS;
    }
    return (y * 4u + x) / 2u;
}

static uint32_t nom_region_from_addr(const void *addr) {
    uintptr_t raw = (uintptr_t)addr;

    return nom_region_from_xy(ADDR_COL(raw), ADDR_ROW(raw));
}

static uint32_t nom_region_master_tid(uint32_t region_id) {
    uint64_t base = get_region_base(region_id);
    uint32_t mx = ADDR_COL(base);
    uint32_t my = ADDR_ROW(base);
    uint32_t cx = ((mx & 1u) != 0u) ? (mx - 1u) : (mx + 1u);

    return (my << (THREAD_OFFSET_BITS + MESH_COORD_BITS)) | (cx << THREAD_OFFSET_BITS);
}

static uint32_t nom_cluster_master_tid(uint32_t x, uint32_t y) {
    return (y << (THREAD_OFFSET_BITS + MESH_COORD_BITS)) | (x << THREAD_OFFSET_BITS);
}

static uint32_t nom_regions_can_copy(uint32_t src_region, uint32_t dst_region) {
    if (src_region >= NUM_REGIONS || dst_region >= NUM_REGIONS || src_region == dst_region) {
        return 0;
    }

    for (uint32_t y = 0; y < 4u; y++) {
        for (uint32_t x = 0; x < 4u; x++) {
            uint32_t tid;

            if (((x + y) & 1u) != 0u) {
                continue;
            }

            tid = nom_cluster_master_tid(x, y);
            if (nom_transfer_can_copy(tid, src_region, dst_region)) {
                return 1;
            }
        }
    }

    return 0;
}

static void nom_send_control(uint32_t sender_tid, uint32_t receiver_tid, uint64_t payload) {
    nom_early_message_t message;

    message.message_id = NOM_TRANSFER_MESSAGE_ID;
    message.sender_tid = sender_tid;
    message.receiver_tid = receiver_tid;
    message.is_broadcast = false;
    message.original_sender_tid = sender_tid;
    message.final_receiver_tid = receiver_tid;
    message.valid = false;
    message.payload = payload;

    nom_early_message(&message);
}

static uint32_t nom_local_reachable_target_mask(uint32_t tid, uint32_t src_region, uint32_t target_mask) {
    uint32_t dst_mask = 0;

    for (uint32_t dst_region = 0; dst_region < NUM_REGIONS; dst_region++) {
        if ((target_mask & (1u << dst_region)) == 0u) {
            continue;
        }

        if (nom_transfer_can_copy(tid, src_region, dst_region)) {
            dst_mask |= 1u << dst_region;
        }
    }

    return dst_mask;
}

static uint32_t nom_route_distance(uint32_t from_region, uint32_t to_region) {
    uint64_t base_from = get_region_base(from_region);
    uint64_t base_to = get_region_base(to_region);
    uint32_t col_from = ADDR_COL(base_from);
    uint32_t col_to = ADDR_COL(base_to);
    uint32_t row_from = ADDR_ROW(base_from);
    uint32_t row_to = ADDR_ROW(base_to);
    
    uint32_t dx = (col_from > col_to) ? (col_from - col_to) : (col_to - col_from);
    uint32_t dy = (row_from > row_to) ? (row_from - row_to) : (row_to - row_from);
    
    return (dx + dy) / 2u;
}

static uint32_t nom_single_target_region(uint32_t target_mask) {
    uint32_t target = NUM_REGIONS;

    for (uint32_t region = 0; region < NUM_REGIONS; region++) {
        if ((target_mask & (1u << region)) == 0u) {
            continue;
        }

        if (target != NUM_REGIONS) {
            return NUM_REGIONS;
        }
        target = region;
    }

    return target;
}

static uint32_t nom_local_delegate_mask(uint32_t tid, uint32_t src_region, uint32_t target_mask) {
    uint32_t target_region = nom_single_target_region(target_mask);

    if (target_region < NUM_REGIONS && (target_mask & (1u << src_region)) == 0u) {
        uint32_t best_mask = 0;
        uint32_t best_dist = NUM_REGIONS;

        for (uint32_t candidate = 0; candidate < NUM_REGIONS; candidate++) {
            uint32_t dist;

            if (!nom_transfer_can_copy(tid, src_region, candidate)) {
                continue;
            }

            if (candidate == target_region) {
                return 1u << candidate;
            }

            dist = nom_route_distance(candidate, target_region);
            if (dist < best_dist) {
                best_dist = dist;
                best_mask = 1u << candidate;
            } else if (dist == best_dist) {
                best_mask |= 1u << candidate;
            }
        }

        return best_mask;
    }

    return nom_local_reachable_target_mask(tid, src_region, target_mask);
}

static uint32_t nom_delegated_transfer(uint32_t tid, uint32_t src_region, uint32_t target_mask,
    uint32_t byte_offset, uint32_t word_count, bool wait_for_ack, bool request_ack) {
    uint32_t dst_mask = nom_local_delegate_mask(tid, src_region, target_mask);
    uint32_t expected_acks = 0;
    uint32_t acked = 0;

    if (dst_mask == 0u) {
        return target_mask == 0u;
    }

    nom_transfer_copy_all(src_region, dst_mask, byte_offset, 0u, word_count);

    for (uint32_t dst_region = 0; dst_region < NUM_REGIONS; dst_region++) {
        uint32_t child_targets;

        if ((dst_mask & (1u << dst_region)) == 0u) {
            continue;
        }
        child_targets = target_mask & ~dst_mask;
        nom_send_control(tid, nom_region_master_tid(dst_region),
            NOM_TRANSFER_PAYLOAD(request_ack ? NOM_TRANSFER_REQ_PAYLOAD : NOM_TRANSFER_REQ_NOACK_PAYLOAD,
                child_targets, byte_offset, word_count));
        if (request_ack) {
            expected_acks++;
        }
    }

    if (!wait_for_ack) {
        return 1;
    }

    while (acked < expected_acks) {
        nom_early_message_t message = nom_early_read_message();

        if (message.valid != NOM_EARLY_MESSAGE_VALID) {
            continue;
        }

        if (message.message_id == NOM_TRANSFER_MESSAGE_ID &&
            NOM_TRANSFER_PAYLOAD_OP(message.payload) == NOM_TRANSFER_ACK_PAYLOAD &&
            NOM_TRANSFER_PAYLOAD_OFFSET(message.payload) == byte_offset) {
            acked++;
        }
    }

    return 1;
}

bool nom_early_transfer_handle_message(nom_early_message_t *message) {
    uint32_t tid;
    uint32_t src_region;
    uint32_t target_mask;
    uint32_t word_count;
    uint32_t op;

    if (message->message_id != NOM_TRANSFER_MESSAGE_ID) {
        return false;
    }

    op = NOM_TRANSFER_PAYLOAD_OP(message->payload);

    if (op == NOM_TRANSFER_ACK_PAYLOAD) {
        return false;
    }

    if (op != NOM_TRANSFER_REQ_PAYLOAD && op != NOM_TRANSFER_REQ_NOACK_PAYLOAD) {
        return false;
    }

    tid = csr_read(CSR_THREAD_ID);
    src_region = get_my_region_id(tid);
    target_mask = NOM_TRANSFER_PAYLOAD_MASK(message->payload);
    word_count = NOM_TRANSFER_PAYLOAD_WORDS(message->payload);

    if (op == NOM_TRANSFER_REQ_PAYLOAD) {
        nom_send_control(tid, message->original_sender_tid,
            NOM_TRANSFER_PAYLOAD(NOM_TRANSFER_ACK_PAYLOAD, 0u, NOM_TRANSFER_PAYLOAD_OFFSET(message->payload), 0u));
    }
    if ((target_mask & ~(1u << get_my_region_id(tid))) != 0u) {
        (void)nom_delegated_transfer(tid, src_region, target_mask,
            NOM_TRANSFER_PAYLOAD_OFFSET(message->payload), word_count, false, false);
    }

    return true;
}

void nom_early_transfer(const uint32_t sender_tid, const uint32_t *src_addr, uint32_t *dst_addr, uint32_t size) {
    uint32_t src_region = nom_region_from_addr(src_addr);
    uint32_t dst_region = nom_region_from_addr(dst_addr);
    uint32_t src_offset = (uint32_t)ADDR_OFFSET(src_addr);
    uint32_t dst_offset = (uint32_t)ADDR_OFFSET(dst_addr);

    if (src_region >= NUM_REGIONS) {
        src_region = get_my_region_id(sender_tid);
    }

    if (dst_region >= NUM_REGIONS || src_offset != dst_offset || size > 0x00ffffffu) {
        for (uint32_t i = 0; i < size; i++) {
            dst_addr[i] = src_addr[i];
        }
        return;
    }

    (void)nom_delegated_transfer(sender_tid, src_region, 1u << dst_region, src_offset, size, true, true);
}

void nom_early_transfer_broadcast(const uint32_t sender_tid, const uint32_t *src_addr, uint32_t *dst_addr, uint32_t size) {
    uint32_t src_region = nom_region_from_addr(src_addr);
    uint32_t src_offset = (uint32_t)ADDR_OFFSET(src_addr);
    uint32_t dst_offset = (uint32_t)ADDR_OFFSET(dst_addr);
    uint32_t target_mask = 0;

    if (src_region >= NUM_REGIONS) {
        src_region = get_my_region_id(sender_tid);
    }

    if (src_offset != dst_offset || size > 0x00ffffffu) {
        for (uint32_t region = 0; region < NUM_REGIONS; region++) {
            volatile uint32_t *dst;

            if (region == src_region) {
                continue;
            }

            dst = (volatile uint32_t *)(get_region_base(region) | dst_offset);
            for (uint32_t i = 0; i < size; i++) {
                dst[i] = src_addr[i];
            }
        }
        return;
    }

    for (uint32_t region = 0; region < NUM_REGIONS; region++) {
        if (region != src_region) {
            target_mask |= 1u << region;
        }
    }

    (void)dst_addr;
    (void)nom_delegated_transfer(sender_tid, src_region, target_mask, src_offset, size, true, true);
}

/*
 * global
 */


/*
 * this first sends a message to the first intermediate memory regions it copies. (i.e. who can touch)
 * then they reply an ack message to the sender, after the copying is done. just after this happen it has no responsibility to the bulk transfer,
 * it deligates it to the next intermediate memory regions in the path.
 * then they sends a message to the next intermediate memory regions it copies, after the copying is done, and so on.
 * - path is dynamically (still simple) determined hop by hop because our message type has enough sematics like
 *   forward?, org. sender, final rec, etc.
 * basically messages guide the bulk transfers.
 * 
 */







/*
 * almost same as nom_early_transfer, but this guratee everyone gets the copy
 * optimized to make the flooding converge is fastest.
 * contrast to the nom_early_transfer it do transfer to the target efficently.
 * both are throughput optimized.
 * both are can be called by calling sites chunked for perfromace.
 */
