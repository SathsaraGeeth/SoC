#ifndef DMCTP_PROC_SCHED_TYPE_H
#define DMCTP_PROC_SCHED_TYPE_H

#include <stdint.h>

/*
 * Comments:
 * 1. Defines an abstract scheduler_t
 */

struct run_queue;
struct task_struct;

/*
 * Original draft:
 *
 * struct sched {
 *     void    (*init)(void);
 *     void    (*enq_task)(task_t *task);
 *     void    (*deq_task)(task_t *task);
 *     task_t *(*pick_next_task)(void);
 * };
 */
struct sched_class {
    void (*enqueue_task)(struct run_queue *, struct task_struct *);
    void (*dequeue_task)(struct run_queue *, struct task_struct *);
    void (*task_tick)(struct run_queue *, struct task_struct *, uint64_t);
    struct task_struct *(*pick_next_task)(struct run_queue *);
};

#endif
