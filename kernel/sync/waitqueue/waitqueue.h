#ifndef WAITQUEUE_H
#define WAITQUEUE_H

#include <stdint.h>
#include "../spinlock/spinlock.h"
#include "../../proc/sched/sched.h"

typedef struct waitqueue_entry waitqueue_entry_t;

struct waitqueue_entry {
    struct task_struct *task;
    waitqueue_entry_t *next;
};

typedef struct waitqueue_head {
    spinlock_t        lock;
    waitqueue_entry_t *head;
} waitqueue_head_t;

void waitqueue_init(waitqueue_head_t *queue);
void waitqueue_add(waitqueue_head_t *queue, waitqueue_entry_t *entry);
void waitqueue_remove(waitqueue_head_t *queue, waitqueue_entry_t *entry);
void wake_up(waitqueue_head_t *queue);
uint32_t wake_up_nr(waitqueue_head_t *queue, uint32_t count);
void wait_event(waitqueue_head_t *queue, int (*condition)(void *), void *data);

#endif /* WAITQUEUE_H */
