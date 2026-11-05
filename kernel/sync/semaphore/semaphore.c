/*
 * kernel/sync/semaphore/semaphore.c
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

#include "semaphore.h"
#include "../../proc/signal/signal.h"

static int semaphore_available(void *data) {
    semaphore_t *sem = data;
    return atomic_read_aint32(&sem->count) > 0;
}

void sem_init(semaphore_t *sem, int32_t initial_count) {
    atomic_write_aint32(&sem->count, initial_count);
    spinlock_init(&sem->lock);
    waitqueue_init(&sem->waiters);
}

int down_trylock(semaphore_t *sem) {
    int32_t old_count;
    spinlock_lock(&sem->lock);
    old_count = atomic_read_aint32(&sem->count);

    if (old_count <= 0) {
        spinlock_unlock(&sem->lock);
        return 1;
    }

    atomic_add_aint32(&sem->count, -1);
    spinlock_unlock(&sem->lock);

    return 0;
}

void down(semaphore_t *sem) {
    while(1) {
        if (down_trylock(sem) == 0) {
            return;
        }

        wait_event(&sem->waiters, semaphore_available, sem);
    }
}

void up(semaphore_t *sem) {
    spinlock_lock(&sem->lock);
    atomic_add_aint32(&sem->count, 1);
    spinlock_unlock(&sem->lock);

    wake_up(&sem->waiters);
}

int down_interruptible(semaphore_t *sem) {
    waitqueue_entry_t entry;
    entry.task = current;
    entry.next = 0;

    while(1) {
        if (down_trylock(sem) == 0) {
            return 0;
        }

        waitqueue_add(&sem->waiters, &entry);

        if (signal_pending(current)) {
            waitqueue_remove(&sem->waiters, &entry);
            return -1;
        }

        set_current_state(TASK_INTERRUPTIBLE);
        schedule();
        __set_current_state(TASK_RUNNING);
        waitqueue_remove(&sem->waiters, &entry);

        if (signal_pending(current)) {
            return -1;
        }
    }
}
