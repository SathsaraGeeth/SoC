#ifndef DMCTP_PROC_EXIT_H
#define DMCTP_PROC_EXIT_H

/*
 * Comments:
 * 1. Defines exit(), do_exit()
 */

#include "../sched/sched.h"

void do_exit(int code, context_t *frame);

#endif
