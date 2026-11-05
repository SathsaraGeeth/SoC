#ifndef DMCTP_PROC_PID_H
#define DMCTP_PROC_PID_H

#include "sched.h"

/*
 * Original draft:
 *
 * struct pid {
 *     uint64_t vtid;
 * }
 */
struct pid {
    uint64_t vtid;
    uint32_t refs;
};

void pid_init(void);
pid_t alloc_pid(void);
void free_pid(pid_t pid);
struct task_struct *find_task_by_pid(pid_t pid);
struct task_struct *task_by_index(uint32_t index);
uint32_t task_count(void);
struct task_struct *task_alloc(void);
void task_release(struct task_struct *task);
void task_model_init(uint32_t nr_cpus);

#endif
