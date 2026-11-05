#include "qspinlock.h"
#include <barrier.h>
#include <cpu_relax.h>

void qspinlock_init(qspinlock_t *lock) {
    atomic_write_aint32(&lock->next, 0);
    atomic_write_aint32(&lock->owner, 0);
}

void qspinlock_lock(qspinlock_t *lock) {
    int32_t ticket = atomic_add_aint32(&lock->next, 1) - 1;

    while (atomic_read_aint32(&lock->owner) != ticket) {
        cpu_relax();
    }
    smp_mb();
}

int qspinlock_trylock(qspinlock_t *lock) {
    int32_t owner = atomic_read_aint32(&lock->owner);

    if (atomic_cmpxchg_aint32(&lock->next, owner, owner + 1) != owner) {
        return 0;
    }
    smp_mb();
    return 1;
}

void qspinlock_unlock(qspinlock_t *lock) {
    smp_mb();
    atomic_add_aint32(&lock->owner, 1);
}
