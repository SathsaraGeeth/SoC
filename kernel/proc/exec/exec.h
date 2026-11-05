#ifndef DMCTP_PROC_EXEC_H
#define DMCTP_PROC_EXEC_H

/*
 * Comments:
 * 1. Defines exec(), execve(), etc.
 */

#include "../sched/sched.h"

int do_execve(context_t *frame, const char *path, const char *const argv[],
              const char *const envp[]);
int do_exec(context_t *frame, const char *path);

#endif
