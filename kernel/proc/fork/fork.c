#include "fork.h"
#include "../process.h"
#include "../signal/signal.h"
#include "../../mm/mapping.h"

static void copy_name(char *destination, const char *source)
{
    uint32_t index = 0;
    while (source && source[index] && index + 1 < PROC_TASK_NAME_LEN) {
        destination[index] = source[index];
        ++index;
    }
    destination[index] = '\0';
}

pid_t copy_process(uint64_t flags, void *stack, const char *name)
{
    struct task_struct *parent = current;
    struct task_struct *child;

    if (!parent)
        return -1;
    if ((flags & CLONE_SIGHAND) && !(flags & CLONE_VM))
        return -1;
    if ((flags & CLONE_THREAD) && !(flags & CLONE_SIGHAND))
        return -1;

    child = process_create(0, name ? name : parent->comm, parent);
    if (!child)
        return -1;

    child->flags = parent->flags & PF_KTHREAD;
    child->policy = parent->policy;
    child->prio = parent->prio;
    child->static_prio = parent->static_prio;
    child->normal_prio = parent->normal_prio;
    child->threads_allowed = parent->threads_allowed;
    child->context = parent->context;
    child->context.r10 = 0;
    child->tgid = (flags & CLONE_THREAD) ? parent->tgid : child->pid;
    child->fs = parent->fs;
    copy_name(child->comm, name ? name : parent->comm);

    if (stack)
        child->context.r2 = (uintptr_t)stack;

    if (process_copy_mm(child, parent, (flags & CLONE_VM) != 0) < 0)
        return -1;
    process_copy_files(child, parent, (flags & CLONE_FILES) != 0);

    signal_copy_task(child, parent, (flags & CLONE_SIGHAND) != 0);
    if (flags & CLONE_THREAD) {
        child->is_thread = 1;
        list_add_tail(&child->thread_group, &parent->thread_group);
    }
    /* A userspace thread needs entry/stack/argument fields that are supplied
     * by process_thread_create() after this generic clone is complete.  Do not
     * publish a partially initialized thread to another CPU. */
    if (!(flags & CLONE_THREAD))
        sched_enqueue(child);
    return child->pid;
}

pid_t kernel_clone(uint64_t flags, void *stack, const char *name)
{
    return copy_process(flags, stack, name);
}

pid_t do_fork(void)
{
    return copy_process(0, 0, 0);
}

pid_t do_clone(uint64_t flags, void *stack)
{
    return copy_process(flags, stack, 0);
}
