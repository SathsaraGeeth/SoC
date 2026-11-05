#include <syscall/syscall.h>
#include <syscall/usercopy.h>
#include <proc/process.h>
#include <proc/fork/fork.h>
#include <proc/exec/exec.h>
#include <proc/exit/exit.h>
#include <proc/wait/wait.h>
#include <proc/sched/pid.h>

struct user_procinfo {
    int32_t pid;
    int32_t ppid;
    uint32_t state;
    char name[16];
};

int64_t sys_exit(struct trap_frame *frame)
{
    do_exit((int)syscall_arg(frame, 0), frame);
    return 0;
}

int64_t sys_exit_group(struct trap_frame *frame)
{
    return sys_exit(frame);
}

int64_t sys_fork(struct trap_frame *frame)
{
    current->context = *frame;
    return do_fork();
}

int64_t sys_vfork(struct trap_frame *frame)
{
    current->context = *frame;
    return do_clone(CLONE_VM, 0);
}

int64_t sys_exec(struct trap_frame *frame)
{
    char path[128];
    if (copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                              sizeof(path)) < 0)
        return -1;
    return do_exec(frame, path);
}

int64_t sys_wait(struct trap_frame *frame)
{
    return do_wait(frame, (int32_t *)syscall_arg(frame, 0));
}

int64_t sys_waitpid(struct trap_frame *frame)
{
    return do_waitpid(frame, (pid_t)syscall_arg(frame, 0),
                      (int32_t *)syscall_arg(frame, 1), 0);
}

int64_t sys_clone(struct trap_frame *frame)
{
    return process_thread_create(syscall_arg(frame, 0), syscall_arg(frame, 1),
                                 syscall_arg(frame, 2), syscall_arg(frame, 3));
}

int64_t sys_thread_join(struct trap_frame *frame)
{
    return do_waitpid(frame, (pid_t)syscall_arg(frame, 0),
                      (int32_t *)syscall_arg(frame, 1), 0);
}

int64_t sys_getpid(struct trap_frame *frame)
{
    (void)frame;
    return current ? current->pid : 0;
}

int64_t sys_getppid(struct trap_frame *frame)
{
    (void)frame;
    return current && current->parent ? current->parent->pid : 0;
}

int64_t sys_gettid(struct trap_frame *frame)
{
    return sys_getpid(frame);
}

int64_t sys_yield(struct trap_frame *frame)
{
    process_schedule(frame);
    return 0;
}

int64_t sys_set_priority(struct trap_frame *frame)
{
    uint32_t old;
    if (!current)
        return -1;
    old = current->static_prio;
    current->static_prio = (uint32_t)syscall_arg(frame, 0);
    current->normal_prio = current->static_prio;
    current->prio = current->normal_prio;
    return old;
}

int64_t sys_get_priority(struct trap_frame *frame)
{
    (void)frame;
    return current ? current->prio : -1;
}

int64_t sys_procinfo(struct trap_frame *frame)
{
    struct task_struct *task =
        task_by_index((uint32_t)syscall_arg(frame, 0));
    struct user_procinfo info = {0};
    uint32_t index;
    if (!task)
        return 0;
    info.pid = task->pid;
    info.ppid = task->parent ? task->parent->pid : 0;
    if (task == current) info.state = 1;
    else if (task->state == TASK_RUNNING) info.state = 0;
    else if (task->state == TASK_ZOMBIE) info.state = 2;
    else if (task->state == TASK_DEAD) info.state = 3;
    else info.state = 4;
    for (index = 0; index + 1 < sizeof(info.name) && task->comm[index]; ++index)
        info.name[index] = task->comm[index];
    return copy_to_user((void *)syscall_arg(frame, 1), &info, sizeof(info)) < 0
        ? -1 : 1;
}
