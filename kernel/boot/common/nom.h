/* 
 * nom.h
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. the read message returns the oldest message and invalidates it so that slot available for new messages.
 *    then it age every message by 1. this facillates ordered, and gurateed delivery of messages. contranst to
 *    trnasfers which are best effort.
 * 2. Messages are latency optimized and transfers are throughput optimized.
 * 3. Message delivery is gurateed and ordered. Transfers are best effort and not gurateed.
 */

#ifndef NOM_H
#define NOM_H

#include <stdint.h>
#include <soc.h>
#include <stdbool.h>

#define NOM_EARLY_MAILBOX_BASE  BL2_HEAP_BASE
#define NOM_EARLY_MAX_MESSAGES  32u
#define NOM_EARLY_MAILBOX_SIZE  sizeof(nom_early_mailbox_t)
#define NOM_EARLY_MESSAGE_VALID true

typedef struct {
    uint32_t message_id;            /* an unique or pseudo unique identifier. this is not the message dont encode thing here. */
    uint32_t sender_tid;            /* hop based sender - for forwarding */
    uint32_t receiver_tid;          /* hop based receiver - for forwarding */
    bool     is_broadcast;
    uint32_t original_sender_tid;   /* global sender */
    uint32_t final_receiver_tid;    /* global receiver */
    bool     valid;
    uint64_t payload;               /* payload - the actual message could be ack/signal/etc */
} nom_early_message_t;

typedef struct {
    nom_early_message_t   messages[NOM_EARLY_MAX_MESSAGES];
    uint32_t              head;     /* write index, updated atomically by senders */
    uint32_t              tail;     /* read index, updated by receiver */
    bool                  valid;
} nom_early_mailbox_t;


/* primitives/local+global - nom_msg.c */
nom_early_mailbox_t nom_early_init(void);
nom_early_message_t nom_early_read_message(void);
void nom_early_message(nom_early_message_t *message);
bool nom_early_transfer_handle_message(nom_early_message_t *message);

/* primitives/local - nom_transfer.c */
bool nom_transfer_can_touch(uint32_t tid, uint32_t region_id);
bool nom_transfer_can_copy(uint32_t tid, uint32_t src_region, uint32_t dst_region);
void nom_transfer_copy_lane(uint32_t src_region, uint32_t dst_mask, uint32_t byte_offset,
                            uint32_t start_word, uint32_t word_count, uint32_t lane, uint32_t stride);
void nom_transfer_copy_all(uint32_t src_region, uint32_t dst_mask, uint32_t byte_offset, 
                            uint32_t start_word, uint32_t word_count);                            
void nom_transfer_worker_loop(uint32_t tid);
void nom_transfer_stop_workers(void);

/* composite/global - nom.c */
void nom_early_transfer(const uint32_t sender_tid, const uint32_t *src_addr, uint32_t *dst_addr, uint32_t size);
void nom_early_transfer_broadcast(const uint32_t sender_tid, const uint32_t *src_addr, uint32_t *dst_addr, uint32_t size);

#endif /* NOM_H */
