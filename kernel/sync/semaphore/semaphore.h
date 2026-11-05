/*
 * kernel/sync/semaphore/semaphore.h
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

#ifndef SEMAPHORE_H
#define SEMAPHORE_H

#include <spinlock.h>
#include <waitqueue.h>
#include <stdint.h>
#include <atomic.h>

typedef struct semaphore {
    aint32_t            count;
    spinlock_t          lock;
    waitqueue_head_t    waiters;
} semaphore_t;

void sem_init(semaphore_t *sem, int32_t initial_count);
void down(semaphore_t *sem);
int  down_trylock(semaphore_t *sem);
int  down_interruptible(semaphore_t *sem);
void up(semaphore_t *sem);

#endif /* SEMAPHORE_H */
