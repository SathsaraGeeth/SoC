#include "rcu.h"
#include <atomic.h>
#include <spinlock.h>
#include <cpu_relax.h>

static aint32_t rcu_readers;
static spinlock_t rcu_callback_lock;
static rcu_head_t *rcu_callbacks;

void rcu_init(void) {
    atomic_write_aint32(&rcu_readers, 0);
    spinlock_init(&rcu_callback_lock);
    rcu_callbacks = 0;
}

void rcu_read_lock(void) {
    atomic_add_aint32(&rcu_readers, 1);
}

void rcu_read_unlock(void) {
    atomic_add_aint32(&rcu_readers, -1);
}

void synchronize_rcu(void) {
    rcu_head_t *callbacks;

    while (atomic_read_aint32(&rcu_readers) != 0) {
        cpu_relax();
    }

    spinlock_lock(&rcu_callback_lock);
    callbacks = rcu_callbacks;
    rcu_callbacks = 0;
    spinlock_unlock(&rcu_callback_lock);

    while (callbacks) {
        rcu_head_t *head = callbacks;
        callbacks = callbacks->next;
        head->next = 0;
        head->func(head);
    }
}

void call_rcu(rcu_head_t *head, void (*func)(rcu_head_t *head)) {
    head->func = func;
    spinlock_lock(&rcu_callback_lock);
    head->next = rcu_callbacks;
    rcu_callbacks = head;
    spinlock_unlock(&rcu_callback_lock);
}
