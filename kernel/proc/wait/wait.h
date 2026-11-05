#ifndef DMCTP_PROC_WAIT_H
#define DMCTP_PROC_WAIT_H

/*
 * Comments:
 * 1. Defines wait(), waitpid()
 */

#include "../sched/sched.h"

#define WNOHANG 1

pid_t do_wait(context_t *frame, int32_t *status);
pid_t do_waitpid(context_t *frame, pid_t pid, int32_t *status, int options);

#endif
