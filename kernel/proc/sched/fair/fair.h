#ifndef DMCTP_PROC_FAIR_H
#define DMCTP_PROC_FAIR_H

/*
 * Comments:
 * 1. Defines the main sheduler eevdf like
 */

#include "../sched_type.h"

extern const struct sched_class fair_sched_class;

struct fair_run_queue;
void fair_rq_init(struct fair_run_queue *fair);

#endif
