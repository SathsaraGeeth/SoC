#include "futex.h"
#include <spinlock.h>
#include "../../proc/sched/sched.h"

#define FUTEX_BUCKET_COUNT 64

typedef struct futex_waiter futex_waiter_t;

struct futex_waiter {
    volatile uint32_t *address;
    struct task_struct *task;
    futex_waiter_t     *next;
    volatile uint32_t   woken;
};

typedef struct futex_bucket {
    spinlock_t     lock;
    futex_waiter_t *head;
} futex_bucket_t;

static futex_bucket_t futex_buckets[FUTEX_BUCKET_COUNT];

static uint32_t futex_hash(const volatile uint32_t *address) {
    uintptr_t value = (uintptr_t)address;
    return (uint32_t)((value >> 2) & (FUTEX_BUCKET_COUNT - 1));
}

void futex_init(void) {
    uint32_t bucket;

    for (bucket = 0; bucket < FUTEX_BUCKET_COUNT; bucket++) {
        spinlock_init(&futex_buckets[bucket].lock);
        futex_buckets[bucket].head = 0;
    }
}

int futex_wait(volatile uint32_t *address, uint32_t expected) {
    futex_bucket_t *bucket = &futex_buckets[futex_hash(address)];
    futex_waiter_t waiter = {
        .address = address,
        .task = current,
        .next = 0,
        .woken = 0
    };

    spinlock_lock(&bucket->lock);
    if (__atomic_load_n(address, __ATOMIC_ACQUIRE) != expected) {
        spinlock_unlock(&bucket->lock);
        return -1;
    }

    waiter.next = bucket->head;
    bucket->head = &waiter;
    set_current_state(TASK_UNINTERRUPTIBLE);
    spinlock_unlock(&bucket->lock);

    while (!waiter.woken) {
        schedule();
    }
    __set_current_state(TASK_RUNNING);
    return 0;
}

int futex_wake(volatile uint32_t *address, uint32_t count) {
    futex_bucket_t *bucket = &futex_buckets[futex_hash(address)];
    futex_waiter_t **link;
    uint32_t woken = 0;

    spinlock_lock(&bucket->lock);
    link = &bucket->head;
    while (*link && woken < count) {
        futex_waiter_t *waiter = *link;

        if (waiter->address != address) {
            link = &waiter->next;
            continue;
        }

        *link = waiter->next;
        waiter->next = 0;
        waiter->woken = 1;
        wake_up_process(waiter->task);
        woken++;
    }
    spinlock_unlock(&bucket->lock);
    return (int)woken;
}
