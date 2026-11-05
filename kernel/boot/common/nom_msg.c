#include <stdint.h>
#include <nom.h>
#include <regs.h>

#define NOM_MSG_REGION_OFFSET_MASK 0x00ffffffu
#define NOM_MSG_INVALID_REGION 0xffffffffu

static inline void nom_msg_fence(void) {
    __asm__ volatile ("fence rw, rw" ::: "memory");
}

static inline uint32_t nom_msg_local_offset(const void *addr) {
    return (uint32_t)((uintptr_t)addr & NOM_MSG_REGION_OFFSET_MASK);
}

static volatile nom_early_mailbox_t *nom_msg_mailbox_for_region(uint32_t region_id) {
    uintptr_t address = (uintptr_t)(get_region_base(region_id) |
        nom_msg_local_offset((const void *)(uintptr_t)NOM_EARLY_MAILBOX_BASE));

    return (volatile nom_early_mailbox_t *)address;
}

static volatile nom_early_mailbox_t *nom_msg_local_mailbox(void) {
    uint32_t tid = csr_read(CSR_THREAD_ID);

    return nom_msg_mailbox_for_region(get_my_region_id(tid));
}

static uint32_t nom_msg_region_from_xy(uint32_t x, uint32_t y) {
    if (x >= 4u || y >= 4u || (((x + y) & 1u) == 0u)) {
        return NOM_MSG_INVALID_REGION;
    }
    return (y * 4u + x) / 2u;
}

static uint32_t nom_msg_kth_accessible_region(uint32_t tid, uint32_t k) {
    uint32_t cx = THREAD_COL(tid);
    uint32_t cy = THREAD_ROW(tid);

    if (k == 0u) {
        return (cy > 0u) ? nom_msg_region_from_xy(cx, cy - 1u) : NOM_MSG_INVALID_REGION;
    } else if (k == 1u) {
        return (cx + 1u < 4u) ? nom_msg_region_from_xy(cx + 1u, cy) : NOM_MSG_INVALID_REGION;
    } else if (k == 2u) {
        return (cy + 1u < 4u) ? nom_msg_region_from_xy(cx, cy + 1u) : NOM_MSG_INVALID_REGION;
    } else if (k == 3u) {
        return (cx > 0u) ? nom_msg_region_from_xy(cx - 1u, cy) : NOM_MSG_INVALID_REGION;
    }

    return NOM_MSG_INVALID_REGION;
}

static uint32_t nom_msg_region_master_tid(uint32_t region_id) {
    uint64_t base = get_region_base(region_id);
    uint32_t mx = ADDR_COL(base);
    uint32_t my = ADDR_ROW(base);
    uint32_t cx = ((mx & 1u) != 0u) ? (mx - 1u) : (mx + 1u);

    return (my << (THREAD_OFFSET_BITS + MESH_COORD_BITS)) | (cx << THREAD_OFFSET_BITS);
}

static uint32_t nom_msg_route_distance(uint32_t from_region, uint32_t to_region) {
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

static uint32_t nom_msg_next_hop(uint32_t tid, uint32_t dst_region, uint32_t prev_region) {
    uint32_t local_region = get_my_region_id(tid);
    uint32_t best_region = NOM_MSG_INVALID_REGION;
    uint32_t best_dist = NOM_MSG_INVALID_REGION;
    uint32_t fallback_region = NOM_MSG_INVALID_REGION;
    uint32_t fallback_dist = NOM_MSG_INVALID_REGION;

    if (local_region == dst_region) {
        return dst_region;
    }

    for (uint32_t k = 0; k < 4u; k++) {
        uint32_t region = nom_msg_kth_accessible_region(tid, k);
        uint32_t dist;

        if (region == NOM_MSG_INVALID_REGION || region == local_region) {
            continue;
        }

        if (region == dst_region) {
            return region;
        }

        dist = nom_msg_route_distance(region, dst_region);
        if (dist == NOM_MSG_INVALID_REGION) {
            continue;
        }

        if (region == prev_region) {
            if (fallback_region == NOM_MSG_INVALID_REGION ||
                dist < fallback_dist ||
                (dist == fallback_dist && region < fallback_region)) {
                fallback_region = region;
                fallback_dist = dist;
            }
            continue;
        }

        if (best_region == NOM_MSG_INVALID_REGION ||
            dist < best_dist ||
            (dist == best_dist && region < best_region)) {
            best_region = region;
            best_dist = dist;
        }
    }

    return (best_region != NOM_MSG_INVALID_REGION) ? best_region : fallback_region;
}

static void nom_msg_clear(nom_early_message_t *message) {
    message->message_id = 0;
    message->sender_tid = 0;
    message->receiver_tid = 0;
    message->is_broadcast = false;
    message->original_sender_tid = 0;
    message->final_receiver_tid = 0;
    message->valid = false;
    message->payload = 0;
}

static void nom_msg_store(uint32_t region_id, const nom_early_message_t *message) {
    volatile nom_early_mailbox_t *mailbox = nom_msg_mailbox_for_region(region_id);
    uint32_t head;
    uint32_t next;
    uint32_t ret;

    for (;;) {
        head = load_reserved(&mailbox->head);
        next = (head + 1) % NOM_EARLY_MAX_MESSAGES;
        
        if (next == mailbox->tail) {
            (void)nom_early_read_message();
            continue;
        }
        
        ret = store_conditional(&mailbox->head, next);
        if (ret == 0) {
            mailbox->messages[head].message_id = message->message_id;
            mailbox->messages[head].sender_tid = message->sender_tid;
            mailbox->messages[head].receiver_tid = message->receiver_tid;
            mailbox->messages[head].is_broadcast = message->is_broadcast;
            mailbox->messages[head].original_sender_tid = message->original_sender_tid;
            mailbox->messages[head].final_receiver_tid = message->final_receiver_tid;
            mailbox->messages[head].payload = message->payload;
            nom_msg_fence();
            mailbox->messages[head].valid = NOM_EARLY_MESSAGE_VALID;
            mailbox->valid = true;
            nom_msg_fence();
            return;
        }
    }
}

/*
 * Initializes a mailbox view. and return it.
 */
nom_early_mailbox_t nom_early_init(void) {
    volatile nom_early_mailbox_t *mailbox = nom_msg_local_mailbox();
    nom_early_mailbox_t view;

    for (uint32_t i = 0; i < NOM_EARLY_MAX_MESSAGES; i++) {
        mailbox->messages[i].valid = false;
        mailbox->messages[i].message_id = 0;
        mailbox->messages[i].sender_tid = 0;
        mailbox->messages[i].receiver_tid = 0;
        mailbox->messages[i].is_broadcast = false;
        mailbox->messages[i].original_sender_tid = 0;
        mailbox->messages[i].final_receiver_tid = 0;
        mailbox->messages[i].payload = 0;

        view.messages[i].valid = false;
        view.messages[i].message_id = 0;
        view.messages[i].sender_tid = 0;
        view.messages[i].receiver_tid = 0;
        view.messages[i].is_broadcast = false;
        view.messages[i].original_sender_tid = 0;
        view.messages[i].final_receiver_tid = 0;
        view.messages[i].payload = 0;
    }

    mailbox->head = 0;
    mailbox->tail = 0;
    mailbox->valid = true;
    nom_msg_fence();

    view.head = 0;
    view.tail = 0;
    view.valid = true;
    return view;
}
/*
 * Returns the oldest message. invalidates that slot. and ages every message by +1.
 */
nom_early_message_t nom_early_read_message(void) {
    volatile nom_early_mailbox_t *mailbox = nom_msg_local_mailbox();
    uint32_t local_tid = csr_read(CSR_THREAD_ID);
    uint32_t local_region = get_my_region_id(local_tid);
    nom_early_message_t message;

    nom_msg_clear(&message);

    for (;;) {
        uint32_t tail = mailbox->tail;
        
        if (tail == mailbox->head) {
            return message;
        }

        if (mailbox->messages[tail].valid != NOM_EARLY_MESSAGE_VALID) {
            continue;
        }

        message.message_id = mailbox->messages[tail].message_id;
        message.sender_tid = mailbox->messages[tail].sender_tid;
        message.receiver_tid = mailbox->messages[tail].receiver_tid;
        message.is_broadcast = mailbox->messages[tail].is_broadcast;
        message.original_sender_tid = mailbox->messages[tail].original_sender_tid;
        message.final_receiver_tid = mailbox->messages[tail].final_receiver_tid;
        message.valid = mailbox->messages[tail].valid;
        message.payload = mailbox->messages[tail].payload;

        nom_msg_fence();
        mailbox->messages[tail].valid = false;
        mailbox->tail = (tail + 1) % NOM_EARLY_MAX_MESSAGES;
        nom_msg_fence();

        if (message.is_broadcast || get_my_region_id(message.final_receiver_tid) == local_region) {
            if (nom_early_transfer_handle_message(&message)) {
                nom_msg_clear(&message);
                continue;
            }
            return message;
        }

        nom_early_message(&message);
        nom_msg_clear(&message);
    }
}
/*
 * Add a message to the mailbox.
 */
void nom_early_message(nom_early_message_t *message) {
    uint32_t local_tid = csr_read(CSR_THREAD_ID);
    uint32_t local_region = get_my_region_id(local_tid);

    if (message->is_broadcast) {
        for (uint32_t region = 0; region < NUM_REGIONS; region++) {
            if (region == local_region) {
                continue;
            }

            message->sender_tid = local_tid;
            message->receiver_tid = nom_msg_region_master_tid(region);
            message->final_receiver_tid = message->receiver_tid;
            nom_msg_store(region, message);
        }
        return;
    }

    {
        uint32_t dst_region = get_my_region_id(message->final_receiver_tid);
        uint32_t prev_region = get_my_region_id(message->sender_tid);
        uint32_t next_region = nom_msg_next_hop(local_tid, dst_region, prev_region);

        if (next_region == NOM_MSG_INVALID_REGION) {
            return;
        }

        message->sender_tid = local_tid;
        message->receiver_tid = nom_msg_region_master_tid(next_region);
        nom_msg_store(next_region, message);
    }
}
