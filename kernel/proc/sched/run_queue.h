#ifndef DMCTP_PROC_RUN_QUEUE_H
#define DMCTP_PROC_RUN_QUEUE_H

#include <stdint.h>
#include "../../sync/spinlock.h"
#include "fair/sched_entity.h"

struct task_struct;

struct fair_run_queue {
    struct list_head tasks;
    uint64_t min_vruntime;
    uint64_t total_weight;
    uint32_t nr_running;
};

/*
 * Original draft:
 *
 * struct run_queue {
 *     spinlock_t    lock;
 *     uint64_t      tid;     // cpu
 *     struct task   *curr;
 *     struct task   *idle;
 *     struct task   *stop;
 *     uint64_t      nr_running;
 *     struct sched  *fair_sched;
 * }
 */
struct run_queue {
    spinlock_t lock;
    uint32_t cpu;
    struct task_struct *curr;
    struct task_struct *idle;
    struct task_struct *stop;
    uint32_t nr_running;
    uint32_t need_resched;
    uint64_t clock;
    struct fair_run_queue fair;
};

#endif
