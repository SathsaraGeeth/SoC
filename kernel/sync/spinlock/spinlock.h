#ifndef SPINLOCK_H
#define SPINLOCK_H

#include <stdint.h>

#define SPINLOCK_UNLOCKED 0
#define SPINLOCK_LOCKED   1

typedef struct {
    volatile uint32_t lock;
} spinlock_t;

void spinlock_init(spinlock_t *lock);
int  spinlock_trylock(spinlock_t *lock);
void spinlock_lock(spinlock_t *lock);
void spinlock_unlock(spinlock_t *lock);
void spinlock_lock_irqsave(spinlock_t *lock, uint64_t *flags);
void spinlock_unlock_irqrestore(spinlock_t *lock, uint64_t flags);

void spin_lock(spinlock_t *lock);
void spin_unlock(spinlock_t *lock);

#endif /* SPINLOCK_H */
