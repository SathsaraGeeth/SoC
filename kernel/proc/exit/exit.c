#include "exit.h"
#include "../process.h"
#include "../sched/pid.h"
#include "../signal/signal.h"

static void reparent_children(struct task_struct *task)
{
    struct task_struct *init = find_task_by_pid(1);
    while (!list_empty(&task->children)) {
        struct list_head *node = task->children.next;
        struct task_struct *child =
            list_entry(node, struct task_struct, sibling);
        list_del_init(node);
        child->parent = init == task ? 0 : init;
        if (child->parent)
            list_add_tail(node, &child->parent->children);
    }
}

void do_exit(int code, context_t *frame)
{
    struct task_struct *task = current;
    if (!task || !frame)
        return;
    task->flags |= PF_EXITING;
    task->exit_code = code;
    reparent_children(task);
    process_release_resources(task);
    task->state = TASK_ZOMBIE;
    if (task->parent) {
        struct task_struct *parent = task->parent;
        if (parent->waiting_for &&
            (parent->waiting_for == -1 || parent->waiting_for == task->pid)) {
            pid_t pid = task->pid;
            parent->context.r10 = (uintptr_t)pid;
            parent->context.r11 = (uintptr_t)(int64_t)task->exit_code;
            parent->waiting_for = 0;
            parent->wait_status = 0;
            list_del_init(&task->sibling);
            process_defer_reap(task);
        }
        send_sig(SIGCHLD, parent);
        wake_up_process(parent);
    }
    process_schedule(frame);
}
