#ifndef DMCTP_THREAD_H
#define DMCTP_THREAD_H
#include <stddef.h>
#include <sys/types.h>

typedef pid_t thread_t;
typedef void *(*thread_fn_t)(void *);

int thread_create(thread_t *thread, thread_fn_t fn, void *arg,
                  void *stack, size_t stack_size);
int thread_join(thread_t thread);
void thread_exit(void) __attribute__((noreturn));

#endif
