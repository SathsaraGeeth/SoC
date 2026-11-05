/*
 * kernel/sync/seqlock/seqlock.c
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

#include "seqlock.h"
#include <barrier.h>
#include <cpu_relax.h>

void seqlock_init(seqlock_t *lock) {
    lock->sequence = 0;
    spinlock_init(&lock->lock);
}

uint32_t read_seqbegin(const seqlock_t *lock) {
    uint32_t sequence;

    do {
        sequence = lock->sequence;
        if (sequence & 1) {
            cpu_relax();
        }
    } while (sequence & 1);
    smp_rmb();
    return sequence;
}

int read_seqretry(const seqlock_t *lock, uint32_t start) {
    smp_rmb();
    return lock->sequence != start;
}

void write_seqlock(seqlock_t *lock) {
    spinlock_lock(&lock->lock);
    lock->sequence++;
    smp_wmb();
}

void write_sequnlock(seqlock_t *lock) {
    smp_wmb();
    lock->sequence++;
    spinlock_unlock(&lock->lock);
}
