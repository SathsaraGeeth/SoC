#include "wait.h"
#include "../process.h"
#include "../sched/pid.h"

static int pid_matches(pid_t wanted, const struct task_struct *child)
{
    if (wanted == -1)
        return 1;
    if (wanted > 0)
        return child->pid == wanted;
    if (wanted == 0)
        return current && child->tgid == current->tgid;
    return 0;
}

pid_t do_waitpid(context_t *frame, pid_t pid, int32_t *status, int options)
{
    struct list_head *node;
    int found = 0;
    if (!current || !frame)
        return -1;
    for (node = current->children.next; node != &current->children;
         node = node->next) {
        struct task_struct *child =
            list_entry(node, struct task_struct, sibling);
        pid_t reaped;
        if (!pid_matches(pid, child))
            continue;
        found = 1;
        if (child->state != TASK_ZOMBIE)
            continue;
        reaped = child->pid;
        frame->r11 = (uint64_t)(int64_t)child->exit_code;
        if (status)
            *status = child->exit_code;
        list_del_init(&child->sibling);
        process_reap_task(child);
        return reaped;
    }
    if (!found)
        return -1;
    if (options & WNOHANG)
        return 0;
    current->waiting_for = pid;
    current->wait_status = status;
    current->state = TASK_INTERRUPTIBLE;
    process_schedule(frame);
    return 0;
}

pid_t do_wait(context_t *frame, int32_t *status)
{
    return do_waitpid(frame, -1, status, 0);
}
