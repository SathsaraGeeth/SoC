#ifndef DMCTP_PROC_FORK_H
#define DMCTP_PROC_FORK_H

/*
 * Comments:
 * 1. Defines fork(), clone()
 */

#include "../sched/sched.h"

#define CLONE_VM      (1ULL << 0)
#define CLONE_FILES   (1ULL << 1)
#define CLONE_SIGHAND (1ULL << 2)
#define CLONE_THREAD  (1ULL << 3)

pid_t copy_process(uint64_t flags, void *stack, const char *name);
pid_t kernel_clone(uint64_t flags, void *stack, const char *name);
pid_t do_fork(void);
pid_t do_clone(uint64_t flags, void *stack);

#endif
