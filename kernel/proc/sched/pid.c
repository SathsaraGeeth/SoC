/*
 * Comments:
 * 1. manages PID (vtid)
 */

#include "pid.h"
#include "../../sync/spinlock.h"
#include "../signal/signal.h"

static struct task_struct task_table[PROC_MAX_TASKS];
static uint64_t pid_map;
static spinlock_t pid_lock = { SPINLOCK_UNLOCKED };

static void zero_bytes(void *ptr, size_t size)
{
    unsigned char *out = ptr;
    while (size--)
        *out++ = 0;
}

void pid_init(void)
{
    uint32_t i;
    spin_lock(&pid_lock);
    pid_map = 1; /* PID zero is the scheduler/idle namespace. */
    for (i = 0; i < PROC_MAX_TASKS; ++i) {
        zero_bytes(&task_table[i], sizeof(task_table[i]));
        task_table[i].state = TASK_DEAD;
    }
    spin_unlock(&pid_lock);
}

pid_t alloc_pid(void)
{
    uint32_t bit;
    spin_lock(&pid_lock);
    for (bit = 1; bit < PROC_MAX_TASKS; ++bit) {
        uint64_t mask = 1ULL << bit;
        if (!(pid_map & mask)) {
            pid_map |= mask;
            spin_unlock(&pid_lock);
            return (pid_t)bit;
        }
    }
    spin_unlock(&pid_lock);
    return -1;
}

void free_pid(pid_t pid)
{
    if (pid <= 0 || pid >= PROC_MAX_TASKS)
        return;
    spin_lock(&pid_lock);
    pid_map &= ~(1ULL << (uint32_t)pid);
    spin_unlock(&pid_lock);
}

struct task_struct *task_alloc(void)
{
    pid_t pid = alloc_pid();
    struct task_struct *task;

    if (pid < 0)
        return 0;
    task = &task_table[pid];
    zero_bytes(task, sizeof(*task));
    task->pid = pid;
    task->tgid = pid;
    task->state = TASK_RUNNING;
    task->prio = task->static_prio = task->normal_prio = 120;
    task->se.load.weight = PROC_NICE_0_LOAD;
    task->se.slice = PROC_DEFAULT_SLICE;
    list_init(&task->children);
    list_init(&task->sibling);
    list_init(&task->se.group_node);
    list_init(&task->thread_group);
    list_init(&task->child_wait.tasks);
    list_init(&task->tasks);
    signal_init_task(task);
    return task;
}

void task_release(struct task_struct *task)
{
    pid_t pid;
    if (!task)
        return;
    pid = task->pid;
    task->state = TASK_DEAD;
    task->pid = 0;
    free_pid(pid);
}

struct task_struct *find_task_by_pid(pid_t pid)
{
    if (pid <= 0 || pid >= PROC_MAX_TASKS)
        return 0;
    if (task_table[pid].state == TASK_DEAD || task_table[pid].pid != pid)
        return 0;
    return &task_table[pid];
}

struct task_struct *task_by_index(uint32_t wanted)
{
    uint32_t index;
    uint32_t seen = 0;
    for (index = 1; index < PROC_MAX_TASKS; ++index) {
        if (task_table[index].state == TASK_DEAD)
            continue;
        if (seen++ == wanted)
            return &task_table[index];
    }
    return 0;
}

uint32_t task_count(void)
{
    uint32_t index;
    uint32_t count = 0;
    for (index = 1; index < PROC_MAX_TASKS; ++index)
        if (task_table[index].state != TASK_DEAD)
            ++count;
    return count;
}

void task_model_init(uint32_t nr_cpus)
{
    pid_init();
    signal_init();
    sched_init(nr_cpus);
}
