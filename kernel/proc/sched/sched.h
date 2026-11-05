#ifndef DMCTP_PROC_SCHED_H
#define DMCTP_PROC_SCHED_H

/*
 * Comments:
 * 1. Defines the taks_t
 */

#include <stddef.h>
#include <stdint.h>
#include "../../trap/trap.h"
#include "fair/sched_entity.h"
#include "run_queue.h"

#define PROC_MAX_TASKS 64
#define PROC_TASK_NAME_LEN 16
#define PROC_DEFAULT_SLICE 4000ULL
#define PROC_NICE_0_LOAD 1024ULL

typedef int32_t pid_t;
typedef struct trap_frame context_t;

enum task_state {
    TASK_RUNNING = 0,
    TASK_INTERRUPTIBLE = 1,
    TASK_UNINTERRUPTIBLE = 2,
    TASK_ZOMBIE = 4,
    TASK_DEAD = 8
};

enum task_flags {
    PF_KTHREAD = 1U << 0,
    PF_EXITING = 1U << 1
};

struct wait_queue_head {
    struct list_head tasks;
};

struct mm;
struct files_struct;
struct signal_struct;

struct fs_struct {
    uint32_t cwd_inode;
};

/*
 * Original draft follows.  It is commented out, not deleted:
 *
 * #include <soc.h> // to know how many threads/cores we have
 *
 * struct taks {
 *     volatile uint64_t state;
 *     uint64_t          flags;
 *     pid_t             pid;
 *     pid_t             tgid;
 *     struct task *parent;
 *     struct list_head children;
 *     struct list_head sibling;
 *     uint64_t prio, static_prio, normal_prio;
 *     uint64_t policy;
 *     struct shed_entity se;
 *     thread_mask_t threads_allowed;
 *     void *stack;
 *     struct mm_struct *mm;
 *     struct mm_struct *active_mm;
 *     struct files_struct *files;
 *     struct signal_struct *signal;
 *     struct sighand_struct *sighand;
 *     struct cred *cred;
 *     struct list_head thread_group;
 *     wait_queue_head_t *wait;
 *     struct list_head tasks;
 * }
 */
struct task_struct {
    volatile uint64_t state;
    uint64_t flags;
    pid_t pid;
    pid_t tgid;
    struct task_struct *parent;
    struct list_head children;
    struct list_head sibling;
    int32_t exit_code;
    pid_t waiting_for;
    int32_t *wait_status;
    uint32_t prio;
    uint32_t static_prio;
    uint32_t normal_prio;
    uint32_t policy;
    uint32_t cpu;
    struct sched_entity se;
    uint64_t threads_allowed;
    void *stack;
    context_t context;
    struct mm *mm;
    struct mm *active_mm;
    struct files_struct *files;
    struct fs_struct fs;
    struct signal_struct *signal;
    struct signal_struct *sighand;
    void *cred;
    struct list_head thread_group;
    struct wait_queue_head child_wait;
    struct list_head tasks;
    char comm[PROC_TASK_NAME_LEN];
    char exec_path[128];
    uint32_t is_thread;
};

typedef struct task_struct task_t;

struct task_struct *sched_current(void);
#define current (sched_current())

void sched_init(uint32_t nr_cpus);
struct run_queue *cpu_rq(uint32_t cpu);
void sched_set_cpu(uint32_t cpu);
uint32_t sched_cpu(void);
void sched_set_current(struct task_struct *task);
void sched_set_idle(struct task_struct *task);
void schedule(void);
void schedule_preempt_disabled(void);
void wake_up_process(struct task_struct *task);
void set_current_state(long state);
void __set_current_state(long state);
int need_resched(void);
void scheduler_tick(void);
void schedule_from_trap(context_t *frame);
struct task_struct *pick_next_task(struct run_queue *rq);
void sched_enqueue(struct task_struct *task);
void sched_dequeue(struct task_struct *task);
struct task_struct *sched_take_next(void);
void switch_to(struct task_struct *prev, struct task_struct *next);

void list_init(struct list_head *head);
int list_empty(const struct list_head *head);
void list_add_tail(struct list_head *node, struct list_head *head);
void list_del_init(struct list_head *node);

#define list_entry(ptr, type, member) \
    ((type *)((char *)(ptr) - offsetof(type, member)))

#endif
