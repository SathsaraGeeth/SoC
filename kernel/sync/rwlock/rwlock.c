#include "rwlock.h"
#include <barrier.h>
#include <cpu_relax.h>

void rwlock_init(rwlock_t *lock) {
    atomic_write_aint32(&lock->lock, RWLOCK_UNLOCKED);
}

int read_trylock(rwlock_t *lock) {
    int32_t value = atomic_read_aint32(&lock->lock);

    while (value >= RWLOCK_UNLOCKED) {
        if (atomic_cmpxchg_aint32(&lock->lock, value, value + 1) == value) {
            smp_mb();
            return 1;
        }
        value = atomic_read_aint32(&lock->lock);
    }
    return 0;
}

void read_lock(rwlock_t *lock) {
    while (!read_trylock(lock)) {
        cpu_relax();
    }
}

void read_unlock(rwlock_t *lock) {
    smp_mb();
    atomic_add_aint32(&lock->lock, -1);
}

int write_trylock(rwlock_t *lock) {
    if (atomic_cmpxchg_aint32(&lock->lock, RWLOCK_UNLOCKED,
                              RWLOCK_WRITER) == RWLOCK_UNLOCKED) {
        smp_mb();
        return 1;
    }
    return 0;
}

void write_lock(rwlock_t *lock) {
    while (!write_trylock(lock)) {
        cpu_relax();
    }
}

void write_unlock(rwlock_t *lock) {
    smp_mb();
    atomic_write_aint32(&lock->lock, RWLOCK_UNLOCKED);
}
