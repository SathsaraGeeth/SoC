#ifndef RWLOCK_H
#define RWLOCK_H

#include <stdint.h>
#include <atomic.h>

#define RWLOCK_UNLOCKED 0
#define RWLOCK_WRITER  -1

typedef struct rwlock {
    aint32_t lock;
} rwlock_t;

void rwlock_init(rwlock_t *lock);
void read_lock(rwlock_t *lock);
int  read_trylock(rwlock_t *lock);
void read_unlock(rwlock_t *lock);
void write_lock(rwlock_t *lock);
int  write_trylock(rwlock_t *lock);
void write_unlock(rwlock_t *lock);

#endif /* RWLOCK_H */
