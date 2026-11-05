#include "completion.h"
#include "../../proc/signal/signal.h"

static int completion_done(void *data) {
    completion_t *c = data;
    return c->done != 0;
}

void init_completion(completion_t *c) {
    c->done = 0;
    spinlock_init(&c->lock);
    waitqueue_init(&c->wait);
}

void wait_for_completion(completion_t *c) {
    while(1) {
        spinlock_lock(&c->lock);
        if (c->done) {
            c->done--;
            spinlock_unlock(&c->lock);
            return;
        }
        spinlock_unlock(&c->lock);
        wait_event(&c->wait, completion_done, c);
    }
}

int wait_for_completion_interruptible(completion_t *c) {
    while (1) {
        spinlock_lock(&c->lock);
        if (c->done) {
            c->done--;
            spinlock_unlock(&c->lock);
            return 0;
        }
        spinlock_unlock(&c->lock);
        if (signal_pending(current)) {
            return -1;
        }
        wait_event(&c->wait, completion_done, c);
    }
}

void complete(completion_t *c) {
    spinlock_lock(&c->lock);
    c->done++;
    spinlock_unlock(&c->lock);
    wake_up(&c->wait);
}

void complete_all(completion_t *c) {
    spinlock_lock(&c->lock);
    c->done = 0xffffffff;
    spinlock_unlock(&c->lock);
    wake_up(&c->wait);
}
