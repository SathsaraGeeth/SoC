#ifndef SPINLOCK_H
#define SPINLOCK_H

#include <stdint.h>
#include <regs.h>
#include <soc.h>

#define SPINLOCK_UNLOCKED 0
#define SPINLOCK_LOCKED   1

typedef struct {
    volatile uint32_t lock;             /* 0 - unlocked, 1 - locked */
} spinlock_t;

void spin_lock(spinlock_t *lock);
void spin_unlock(spinlock_t *lock);

#endif /* SPINLOCK_H */
