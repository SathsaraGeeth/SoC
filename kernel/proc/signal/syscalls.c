#include <syscall/syscall.h>
#include <proc/signal/signal.h>

int64_t sys_kill(struct trap_frame *frame)
{
    return send_signal((pid_t)syscall_arg(frame, 0),
                       (int)syscall_arg(frame, 1));
}

int64_t sys_sigaction(struct trap_frame *frame)
{
    int signal = (int)syscall_arg(frame, 0);
    struct k_sigaction action = {
        .handler = (sig_handler_t)syscall_arg(frame, 1),
        .mask = (uint32_t)syscall_arg(frame, 2),
        .flags = (uint32_t)syscall_arg(frame, 3)
    };
    struct k_sigaction old;
    if (do_sigaction(signal, &action, &old) < 0)
        return -1;
    return (int64_t)(uintptr_t)old.handler;
}

int64_t sys_sigreturn(struct trap_frame *frame)
{
    sig_return(frame);
    return (int64_t)frame->r10;
}

int64_t sys_sigprocmask(struct trap_frame *frame)
{
    uint32_t old;
    if (!current || !current->signal)
        return -1;
    old = current->signal->blocked;
    current->signal->blocked = (uint32_t)syscall_arg(frame, 0);
    return old;
}
