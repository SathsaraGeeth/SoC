#include <stdint.h>
#include <soc.h>
#include <nom.h>
#include <load.h>
#include <regs.h>
#include <console_early.h>
#include "nom.h"

#define BL1_BL2A_TRANSFER_CHUNK_WORDS 4096u
#define BL1_NOM_MESSAGE_ID 0u
#define CHECKSUM_REQ_PAYLOAD_OP 0xcau
#define CHECKSUM_REP_PAYLOAD_OP 0xcbu
#define CHECKSUM_PAYLOAD(op, value) ((((uint64_t)((op) & 0xffu)) << 56) | ((uint64_t)(value)))
#define CHECKSUM_PAYLOAD_OP(payload) ((uint32_t)(((payload) >> 56) & 0xffu))
#define CHECKSUM_PAYLOAD_VALUE(payload) ((uint32_t)(payload))

static uint32_t compute_sparse_checksum(uintptr_t base_addr, uint32_t size) {
    uint32_t sum = 0;
    const uint32_t *ptr = (const uint32_t *)base_addr;
    for (uint32_t i = 0; i < size / sizeof(uint32_t); i += 16) {
        sum += ptr[i];
    }
    return sum;
}

static uint32_t bl1_get_region_master_tid(uint32_t region_id) {
    uint32_t y = region_id / 2;
    uint32_t x = (region_id % 2) * 2 + (1 - (y % 2));
    uint32_t cx = (x % 2 == 0) ? (x + 1) : (x - 1);
    return (y << (THREAD_OFFSET_BITS + MESH_COORD_BITS)) | (cx << THREAD_OFFSET_BITS);
}

void bl1_nom_secondary_listen_loop(uint32_t tid, uint32_t region_id) {
    for (;;) {
        nom_early_message_t rmsg = nom_early_read_message();
        if (rmsg.valid == NOM_EARLY_MESSAGE_VALID) {
            if (rmsg.message_id == BL1_NOM_MESSAGE_ID &&
                CHECKSUM_PAYLOAD_OP(rmsg.payload) == CHECKSUM_REQ_PAYLOAD_OP) {
                uint32_t sum = compute_sparse_checksum(get_region_base(region_id) | ADDR_OFFSET(BL2_BASE), BL2_SIZE);
                nom_early_message_t rep;
                rep.message_id = BL1_NOM_MESSAGE_ID;
                rep.sender_tid = tid;
                rep.receiver_tid = 0;
                rep.is_broadcast = false;
                rep.original_sender_tid = tid;
                rep.final_receiver_tid = rmsg.original_sender_tid;
                rep.valid = NOM_EARLY_MESSAGE_VALID;
                rep.payload = CHECKSUM_PAYLOAD(CHECKSUM_REP_PAYLOAD_OP, sum);
                nom_early_message(&rep);
            }
        } else {
            for (volatile int i = 0; i < 100; i++) {
                // throttle memory pressure
            }
        }
    }
}

void bl1_nom_transfer_bl2a_to_region(uint32_t tid, uint32_t target_region) {
    for (uint32_t start_word = 0; start_word < (BL2A_SIZE / sizeof(uint32_t)); start_word += BL1_BL2A_TRANSFER_CHUNK_WORDS) {
        uint32_t words = (BL2A_SIZE / sizeof(uint32_t)) - start_word;
        uint32_t byte_offset = start_word * sizeof(uint32_t);
        const uint32_t *src = (const uint32_t *)(KERNEL_BASE + byte_offset);
        uint32_t *dst = (uint32_t *)(get_region_base(target_region) | ADDR_OFFSET(KERNEL_BASE + byte_offset));

        if (words > BL1_BL2A_TRANSFER_CHUNK_WORDS) {
            words = BL1_BL2A_TRANSFER_CHUNK_WORDS;
        }

        nom_early_transfer(tid, src, dst, words);
    }
}

void bl1_nom_transfer_bl2_to_region(uint32_t tid, uint32_t target_region) {
    for (uint32_t start_word = 0; start_word < (BL2_SIZE / sizeof(uint32_t)); start_word += BL1_BL2A_TRANSFER_CHUNK_WORDS) {
        uint32_t words = (BL2_SIZE / sizeof(uint32_t)) - start_word;
        uint32_t byte_offset = start_word * sizeof(uint32_t);
        const uint32_t *src = (const uint32_t *)(BL2_BASE + byte_offset);
        uint32_t *dst = (uint32_t *)(get_region_base(target_region) | ADDR_OFFSET(BL2_BASE + byte_offset));

        if (words > BL1_BL2A_TRANSFER_CHUNK_WORDS) {
            words = BL1_BL2A_TRANSFER_CHUNK_WORDS;
        }

        nom_early_transfer(tid, src, dst, words);
    }
}

void bl1_nom_transfer_bl2_broadcast(uint32_t tid) {
    for (uint32_t start_word = 0; start_word < (BL2_SIZE / sizeof(uint32_t)); start_word += BL1_BL2A_TRANSFER_CHUNK_WORDS) {
        uint32_t words = (BL2_SIZE / sizeof(uint32_t)) - start_word;
        uint32_t byte_offset = start_word * sizeof(uint32_t);
        const uint32_t *src = (const uint32_t *)(BL2_BASE + byte_offset);
        uint32_t *dst = (uint32_t *)(BL2_BASE + byte_offset);

        if (words > BL1_BL2A_TRANSFER_CHUNK_WORDS) {
            words = BL1_BL2A_TRANSFER_CHUNK_WORDS;
        }

        nom_early_transfer_broadcast(tid, src, dst, words);
    }
}

bool bl1_nom_request_and_verify_checksum(uint32_t tid, uint32_t target_region) {
    nom_early_message_t req;
    req.message_id = BL1_NOM_MESSAGE_ID;
    req.sender_tid = tid;
    req.receiver_tid = 0;
    req.is_broadcast = false;
    req.original_sender_tid = tid;
    req.final_receiver_tid = bl1_get_region_master_tid(target_region);
    req.valid = NOM_EARLY_MESSAGE_VALID;
    req.payload = CHECKSUM_PAYLOAD(CHECKSUM_REQ_PAYLOAD_OP, 0u);
    nom_early_message(&req);

    uint32_t my_sum = compute_sparse_checksum(BL2_BASE, BL2_SIZE);

    uint32_t their_sum = 0;
    while(1) {
        nom_early_message_t rep = nom_early_read_message();
        if (rep.valid == NOM_EARLY_MESSAGE_VALID &&
            rep.message_id == BL1_NOM_MESSAGE_ID &&
            CHECKSUM_PAYLOAD_OP(rep.payload) == CHECKSUM_REP_PAYLOAD_OP) {
            their_sum = CHECKSUM_PAYLOAD_VALUE(rep.payload);
            break;
        }
        for (volatile int i = 0; i < 100; i++) {
            // throttle memory pressure
        }
    }

    return (my_sum == their_sum);
}
