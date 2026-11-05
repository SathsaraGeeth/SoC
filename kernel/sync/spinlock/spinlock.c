/*
 * kernel/sync/spinlock/spinlock.c
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

#include "spinlock.h"
#include "../../irq/irq.h"
#include "../atomic/atomic.h"
#include "../barrier/barrier.h"
#include "cpu_relax.h"

void spinlock_init(spinlock_t *lock) {
    atomic_write_aint32((aint32_t *)&lock->lock, 0);
}

void spinlock_lock(spinlock_t *lock) {
    while(atomic_cmpxchg_aint32((aint32_t *)&lock->lock, 0, 1) != 0) {
        cpu_relax();
    }
    smp_mb();
}

int spinlock_trylock(spinlock_t *lock) {
    if (atomic_cmpxchg_aint32((aint32_t *)&lock->lock, 0, 1) == 0) {
        smp_mb();
        return 1;
    }
    return 0;
}

void spinlock_unlock(spinlock_t *lock) {
    smp_mb();
    atomic_write_aint32((aint32_t *)&lock->lock, 0);
}

void spinlock_lock_irqsave(spinlock_t *lock, uint64_t *flags) {
    *flags = irq_save();
    spinlock_lock(lock);
}

void spinlock_unlock_irqrestore(spinlock_t *lock, uint64_t flags) {
    spinlock_unlock(lock);
    irq_restore(flags);
}

void spin_lock(spinlock_t *lock) {
    spinlock_lock(lock);
}

void spin_unlock(spinlock_t *lock) {
    spinlock_unlock(lock);
}
