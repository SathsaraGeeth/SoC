/*
 * kernel/sync/rwsem/rwsem.c
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

#include "rwsem.h"
#include <barrier.h>

static int rwsem_read_available(void *data) {
    rw_semaphore_t *sem = data;
    return atomic_read_aint32(&sem->count) >= RWSEM_UNLOCKED;
}

static int rwsem_write_available(void *data) {
    rw_semaphore_t *sem = data;
    return atomic_read_aint32(&sem->count) == RWSEM_UNLOCKED;
}

void rwsem_init(rw_semaphore_t *sem) {
    atomic_write_aint32(&sem->count, RWSEM_UNLOCKED);
    waitqueue_init(&sem->waiters);
}

int down_read_trylock(rw_semaphore_t *sem) {
    int32_t count = atomic_read_aint32(&sem->count);

    while (count >= RWSEM_UNLOCKED) {
        if (atomic_cmpxchg_aint32(&sem->count, count, count + 1) == count) {
            smp_mb();
            return 1;
        }
        count = atomic_read_aint32(&sem->count);
    }
    return 0;
}

void down_read(rw_semaphore_t *sem) {
    while (!down_read_trylock(sem)) {
        wait_event(&sem->waiters, rwsem_read_available, sem);
    }
}

void up_read(rw_semaphore_t *sem) {
    smp_mb();
    if (atomic_add_aint32(&sem->count, -1) == RWSEM_UNLOCKED) {
        wake_up(&sem->waiters);
    }
}

int down_write_trylock(rw_semaphore_t *sem) {
    if (atomic_cmpxchg_aint32(&sem->count, RWSEM_UNLOCKED,
                              RWSEM_WRITER) == RWSEM_UNLOCKED) {
        smp_mb();
        return 1;
    }
    return 0;
}

void down_write(rw_semaphore_t *sem) {
    while (!down_write_trylock(sem)) {
        wait_event(&sem->waiters, rwsem_write_available, sem);
    }
}

void up_write(rw_semaphore_t *sem) {
    smp_mb();
    atomic_write_aint32(&sem->count, RWSEM_UNLOCKED);
    wake_up(&sem->waiters);
}
