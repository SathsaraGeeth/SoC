#include "fair.h"
#include "../sched.h"

static uint64_t scale_delta(uint64_t delta, uint64_t weight)
{
    uint64_t numerator;
    uint64_t quotient = 0;
    uint64_t remainder = 0;
    int bit;
    if (!weight)
        weight = 1;
    numerator = delta * PROC_NICE_0_LOAD;
    for (bit = 63; bit >= 0; --bit) {
        remainder = (remainder << 1) | ((numerator >> bit) & 1U);
        if (remainder >= weight) {
            remainder -= weight;
            quotient |= 1ULL << bit;
        }
    }
    return quotient;
}

void fair_rq_init(struct fair_run_queue *fair)
{
    list_init(&fair->tasks);
    fair->min_vruntime = 0;
    fair->total_weight = 0;
    fair->nr_running = 0;
}

static void fair_enqueue(struct run_queue *rq, struct task_struct *task)
{
    struct list_head *at;

    if (task->se.on_rq)
        return;
    if (!task->se.load.weight)
        task->se.load.weight = PROC_NICE_0_LOAD;
    if (task->se.vruntime < rq->fair.min_vruntime)
        task->se.vruntime = rq->fair.min_vruntime;
    if (!task->se.slice)
        task->se.slice = PROC_DEFAULT_SLICE;
    task->se.deadline = task->se.vruntime +
        scale_delta(task->se.slice, task->se.load.weight);

    at = rq->fair.tasks.next;
    while (at != &rq->fair.tasks) {
        struct task_struct *pos =
            list_entry(at, struct task_struct, se.group_node);
        if (task->se.deadline < pos->se.deadline)
            break;
        at = at->next;
    }
    task->se.group_node.next = at;
    task->se.group_node.prev = at->prev;
    at->prev->next = &task->se.group_node;
    at->prev = &task->se.group_node;
    task->se.on_rq = 1;
    rq->fair.nr_running++;
    rq->fair.total_weight += task->se.load.weight;
}

static void fair_dequeue(struct run_queue *rq, struct task_struct *task)
{
    if (!task->se.on_rq)
        return;
    list_del_init(&task->se.group_node);
    task->se.on_rq = 0;
    rq->fair.nr_running--;
    rq->fair.total_weight -= task->se.load.weight;
}

static int entity_eligible(const struct fair_run_queue *fair,
                           const struct sched_entity *se)
{
    return se->vruntime <= fair->min_vruntime;
}

static struct task_struct *fair_pick(struct run_queue *rq)
{
    struct list_head *node;
    struct task_struct *fallback = 0;

    for (node = rq->fair.tasks.next; node != &rq->fair.tasks;
         node = node->next) {
        struct task_struct *task =
            list_entry(node, struct task_struct, se.group_node);
        if (!fallback || task->se.vruntime < fallback->se.vruntime)
            fallback = task;
        if (entity_eligible(&rq->fair, &task->se))
            return task;
    }
    return fallback;
}

static void fair_tick(struct run_queue *rq, struct task_struct *task,
                      uint64_t delta)
{
    task->se.sum_exec_runtime += delta;
    task->se.vruntime += scale_delta(delta, task->se.load.weight);
    if (task->se.vruntime > rq->fair.min_vruntime)
        rq->fair.min_vruntime = task->se.vruntime;
    if (task->se.vruntime >= task->se.deadline)
        rq->need_resched = 1;
}

const struct sched_class fair_sched_class = {
    .enqueue_task = fair_enqueue,
    .dequeue_task = fair_dequeue,
    .task_tick = fair_tick,
    .pick_next_task = fair_pick
};
