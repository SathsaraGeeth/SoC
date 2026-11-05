/*
 * kernel/sync/seqlock/seqlock.h
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

#ifndef SEQLOCK_H
#define SEQLOCK_H

#include <stdint.h>
#include <spinlock.h>

typedef struct seqlock {
    volatile uint32_t sequence;
    spinlock_t        lock;
} seqlock_t;

void     seqlock_init(seqlock_t *lock);
uint32_t read_seqbegin(const seqlock_t *lock);
int      read_seqretry(const seqlock_t *lock, uint32_t start);
void     write_seqlock(seqlock_t *lock);
void     write_sequnlock(seqlock_t *lock);

#endif /* SEQLOCK_H */
