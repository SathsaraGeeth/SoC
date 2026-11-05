/*
 * kernel/sync/rwsem/rwsem.h
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

#ifndef RWSEM_H
#define RWSEM_H

#include <stdint.h>
#include <atomic.h>
#include <waitqueue.h>

#define RWSEM_UNLOCKED 0
#define RWSEM_WRITER  -1

typedef struct rw_semaphore {
    aint32_t         count;
    waitqueue_head_t waiters;
} rw_semaphore_t;

void rwsem_init(rw_semaphore_t *sem);
void down_read(rw_semaphore_t *sem);
int  down_read_trylock(rw_semaphore_t *sem);
void up_read(rw_semaphore_t *sem);
void down_write(rw_semaphore_t *sem);
int  down_write_trylock(rw_semaphore_t *sem);
void up_write(rw_semaphore_t *sem);

#endif /* RWSEM_H */
