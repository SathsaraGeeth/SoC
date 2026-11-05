#include <mutex.h>
#include <barrier.h>

static int mutex_available(void *data) {
    mutex_t *mutex = data;
    return atomic_read_aint32(&mutex->lock) == 0;
}

void mutex_init(mutex_t *mutex) {
    atomic_write_aint32(&mutex->lock, 0);
    mutex->owner = 0;
    waitqueue_init(&mutex->waiters);
}

int mutex_trylock(mutex_t *mutex) {
    if (atomic_cmpxchg_aint32(&mutex->lock, 0, 1) == 0) {
        mutex->owner = current;
        smp_mb();
        return 1;
    }
    return 0;
}

void mutex_lock(mutex_t *mutex) {
    while(1) {
        if (mutex_trylock(mutex)) {
            return;
        }
        wait_event(&mutex->waiters, mutex_available, mutex);
    }
}

void mutex_unlock(mutex_t *mutex) {
    smp_mb();
    mutex->owner = 0;

    atomic_write_aint32(&mutex->lock, 0);

    wake_up(&mutex->waiters);
}
