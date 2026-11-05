#ifndef COMPLETION_H
#define COMPLETION_H

#include <stdint.h>
#include <waitqueue.h>
#include <spinlock.h>

typedef struct completion {
    uint32_t        done;
    spinlock_t      lock;
    waitqueue_head_t wait;
} completion_t;

void init_completion(completion_t *c);
void wait_for_completion(completion_t *c);
int  wait_for_completion_interruptible(completion_t *c);
void complete(completion_t *c);
void complete_all(completion_t *c);

#endif /* COMPLETION_H */
