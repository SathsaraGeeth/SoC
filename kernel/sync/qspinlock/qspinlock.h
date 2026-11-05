/*
 * kernel/sync/qspinlock/qspinlock.h
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

#ifndef QSPINLOCK_H
#define QSPINLOCK_H

#include <stdint.h>
#include <atomic.h>

typedef struct qspinlock {
    aint32_t next;
    aint32_t owner;
} qspinlock_t;

void qspinlock_init(qspinlock_t *lock);
void qspinlock_lock(qspinlock_t *lock);
int  qspinlock_trylock(qspinlock_t *lock);
void qspinlock_unlock(qspinlock_t *lock);

#endif /* QSPINLOCK_H */
