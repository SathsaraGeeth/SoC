/*
 * Comments:
 * 1. sheduler main
 * shedule(), context_switch()
 */

#include "sched.h"
#include "fair/fair.h"
#include "../../lib/printk.h"
#include <regs.h>
#include <soc.h>

#define PROC_MAX_CPUS 64

static struct run_queue runqueues[PROC_MAX_CPUS];
static struct task_struct *cpu_current[PROC_MAX_CPUS];
static uint32_t active_cpus = 1;

static uint32_t local_cpu(void)
{
    uint32_t cpu = THREAD_OFFSET(csr_read(CSR_THREAD_ID));
    return cpu < active_cpus ? cpu : 0;
}

void list_init(struct list_head *head)
{
    head->next = head;
    head->prev = head;
}

int list_empty(const struct list_head *head)
{
    return head->next == head;
}

void list_add_tail(struct list_head *node, struct list_head *head)
{
    node->prev = head->prev;
    node->next = head;
    head->prev->next = node;
    head->prev = node;
}

void list_del_init(struct list_head *node)
{
    node->prev->next = node->next;
    node->next->prev = node->prev;
    list_init(node);
}

void sched_init(uint32_t nr_cpus)
{
    uint32_t cpu;

    active_cpus = nr_cpus ? nr_cpus : 1;
    if (active_cpus > PROC_MAX_CPUS)
        active_cpus = PROC_MAX_CPUS;
    for (cpu = 0; cpu < active_cpus; ++cpu) {
        runqueues[cpu].lock.lock = SPINLOCK_UNLOCKED;
        runqueues[cpu].cpu = cpu;
        runqueues[cpu].curr = 0;
        runqueues[cpu].idle = 0;
        runqueues[cpu].stop = 0;
        runqueues[cpu].nr_running = 0;
        runqueues[cpu].need_resched = 0;
        runqueues[cpu].clock = 0;
        fair_rq_init(&runqueues[cpu].fair);
        cpu_current[cpu] = 0;
    }
}

struct run_queue *cpu_rq(uint32_t cpu)
{
    return &runqueues[cpu < active_cpus ? cpu : 0];
}

void sched_set_cpu(uint32_t cpu)
{
    /* CPU identity is a hardware property on DMCTP, not shared kernel state. */
    (void)cpu;
}

uint32_t sched_cpu(void)
{
    return local_cpu();
}

struct task_struct *sched_current(void)
{
    return cpu_current[local_cpu()];
}

void sched_set_current(struct task_struct *task)
{
    uint32_t cpu = local_cpu();
    struct run_queue *rq = cpu_rq(cpu);
    spin_lock(&rq->lock);
    rq->curr = task;
    cpu_current[cpu] = task;
    if (task) task->cpu = cpu;
    spin_unlock(&rq->lock);
}

void sched_set_idle(struct task_struct *task)
{
    struct run_queue *rq = cpu_rq(local_cpu());
    spin_lock(&rq->lock);
    rq->idle = task;
    spin_unlock(&rq->lock);
}

void sched_enqueue(struct task_struct *task)
{
    uint32_t cpu;
    uint32_t target = local_cpu();
    uint32_t smallest = ~(uint32_t)0;
    struct run_queue *rq;

    /* User thread clones are migratable.  Kernel exec trampolines retain the
     * caller CPU until they have entered their userspace image. */
    if (task->is_thread) {
        for (cpu = 0; cpu < active_cpus; ++cpu) {
            struct run_queue *candidate = cpu_rq(cpu);
            uint32_t load = candidate->nr_running;
            /* A freshly cloned thread must not be placed behind its creator:
             * clone/join barriers cannot make progress without preemption. */
            if (active_cpus > 1 && cpu == local_cpu())
                continue;
            if (candidate->curr && candidate->curr != candidate->idle)
                ++load;
            if (load < smallest) {
                smallest = load;
                target = cpu;
            }
        }
    }
    rq = cpu_rq(target);
    spin_lock(&rq->lock);
    fair_sched_class.enqueue_task(rq, task);
    rq->nr_running = rq->fair.nr_running;
    task->cpu = target;
    spin_unlock(&rq->lock);
    if (target != local_cpu())
        ipi_trigger_target(target);
}

void sched_dequeue(struct task_struct *task)
{
    struct run_queue *rq = cpu_rq(task->cpu);
    spin_lock(&rq->lock);
    fair_sched_class.dequeue_task(rq, task);
    rq->nr_running = rq->fair.nr_running;
    spin_unlock(&rq->lock);
}

struct task_struct *pick_next_task(struct run_queue *rq)
{
    struct task_struct *next = fair_sched_class.pick_next_task(rq);
    return next ? next : rq->idle;
}

void schedule(void)
{
    uint32_t cpu = local_cpu();
    struct run_queue *rq = cpu_rq(cpu);
    struct task_struct *prev;
    struct task_struct *next;

    spin_lock(&rq->lock);
    prev = rq->curr;
    if (prev && prev->state == TASK_RUNNING && prev != rq->idle) {
        fair_sched_class.dequeue_task(rq, prev);
        fair_sched_class.enqueue_task(rq, prev);
    }
    next = pick_next_task(rq);
    if (next && next != rq->idle)
        fair_sched_class.dequeue_task(rq, next);
    rq->curr = next;
    rq->nr_running = rq->fair.nr_running;
    rq->need_resched = 0;
    cpu_current[cpu] = next;
    if (next) next->cpu = cpu;
    spin_unlock(&rq->lock);

    if (next && next != prev)
        switch_to(prev, next);
}

void schedule_preempt_disabled(void)
{
    schedule();
}

void wake_up_process(struct task_struct *task)
{
    if (!task || task->state == TASK_DEAD || task->state == TASK_ZOMBIE)
        return;
    /* A running task is either current on a CPU or already runnable.  Adding
     * it again can execute one process concurrently on two hardware threads. */
    if (task->state == TASK_RUNNING)
        return;
    task->state = TASK_RUNNING;
    sched_enqueue(task);
}

void set_current_state(long state)
{
    struct task_struct *task = sched_current();
    if (task)
        task->state = (uint64_t)state;
}

__attribute__((weak)) void finish_task_switch(struct task_struct *next)
{
    (void)next;
}

void schedule_from_trap(context_t *frame)
{
    uint32_t cpu = local_cpu();
    struct run_queue *rq = cpu_rq(cpu);
    struct task_struct *prev;
    struct task_struct *next;

    spin_lock(&rq->lock);
    prev = rq->curr;
    if (prev) {
        prev->context = *frame;
        prev->context.restore_frame = 0;
        if (prev->state == TASK_RUNNING && prev != rq->idle)
            fair_sched_class.enqueue_task(rq, prev);
    }
    next = pick_next_task(rq);
    if (next && next != rq->idle)
        fair_sched_class.dequeue_task(rq, next);
    if (!next)
        next = prev;
    rq->curr = next;
    rq->nr_running = rq->fair.nr_running;
    rq->need_resched = 0;
    cpu_current[cpu] = next;
    if (next) next->cpu = cpu;
    if (next)
        frame->restore_frame = (uintptr_t)&next->context;
    spin_unlock(&rq->lock);
    if (next)
        finish_task_switch(next);
}

void __set_current_state(long state)
{
    set_current_state(state);
}

int need_resched(void)
{
    return cpu_rq(local_cpu())->need_resched != 0;
}

void scheduler_tick(void)
{
    struct run_queue *rq = cpu_rq(local_cpu());
    spin_lock(&rq->lock);
    rq->clock++;
    if (rq->curr && rq->curr != rq->idle)
        fair_sched_class.task_tick(rq, rq->curr, 1);
    spin_unlock(&rq->lock);
}

struct task_struct *sched_take_next(void)
{
    uint32_t cpu = local_cpu();
    struct run_queue *rq = cpu_rq(cpu);
    struct task_struct *next;

    spin_lock(&rq->lock);
    next = fair_sched_class.pick_next_task(rq);
    if (next)
        fair_sched_class.dequeue_task(rq, next);
    rq->curr = next ? next : rq->idle;
    rq->nr_running = rq->fair.nr_running;
    cpu_current[cpu] = rq->curr;
    if (next) next->cpu = cpu;
    spin_unlock(&rq->lock);
    return next;
}
