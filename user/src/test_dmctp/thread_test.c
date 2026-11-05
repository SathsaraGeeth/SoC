#include <stdint.h>
#include <dmctp/thread.h>
#include <unistd.h>

static volatile uint32_t shared_value;
static uint8_t worker_stack[512] __attribute__((aligned(16)));

static void *worker(void *arg) {
    shared_value = (uint32_t)(uintptr_t)arg;
    return 0;
}

int main(void) {
    thread_t thread;
    puts("thread_test: create");
    if (thread_create(&thread, worker, (void *)(uintptr_t)0x12345678u,
                      worker_stack, sizeof(worker_stack)) < 0) {
        puts("thread_test: FAIL create");
        return 1;
    }
    puts("thread_test: join");
    if (thread_join(thread) < 0) {
        puts("thread_test: FAIL join");
        return 1;
    }
    if (shared_value != 0x12345678u) {
        puts("thread_test: FAIL shared memory");
        return 1;
    }
    puts("thread_test: PASS");
    return 0;
}
