/*
 * kernel/sync/mutex/mutex.h
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

#ifndef MUTEX_H
#define MUTEX_H

#include <atomic.h>
#include <waitqueue.h>

typedef struct mutex {
    aint32_t       lock;
    struct task_struct *owner;
    waitqueue_head_t   waiters;
} mutex_t;


void mutex_init(mutex_t *mutex);
void mutex_lock(mutex_t *mutex);
int  mutex_trylock(mutex_t *mutex);
void mutex_unlock(mutex_t *mutex);

#endif /* MUTEX_H */
