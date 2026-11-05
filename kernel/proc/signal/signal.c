#include "signal.h"
#include "../exit/exit.h"
#include "../sched/pid.h"
#include "../../lib/printk.h"
#include "../../syscall/syscall.h"
#include "../../syscall/syscall_numbers.h"

static struct signal_struct signals[PROC_MAX_TASKS];

extern void _sigreturn_trampoline(void);

__attribute__((naked))
void _sigreturn_trampoline(void)
{
    __asm__ volatile (
#ifdef DMCTP_RISCV_COMPAT
        "lui a0, 4\n"
        "addi a0, a0, 257\n"
#else
        "addi.i32 r10, r0, %0\n"
#endif
        "ecall\n" : : "i"(SYS_SIGRETURN)
    );
}

static void clear_signal(struct signal_struct *signal)
{
    int sig;
    signal->pending = 0;
    signal->blocked = 0;
    for (sig = 0; sig <= NSIG; ++sig) {
        signal->action[sig].handler = SIG_DFL;
        signal->action[sig].mask = 0;
        signal->action[sig].flags = 0;
    }
}

void signal_init(void)
{
    uint32_t index;
    for (index = 0; index < PROC_MAX_TASKS; ++index)
        clear_signal(&signals[index]);
}

void signal_init_task(struct task_struct *task)
{
    if (!task || task->pid <= 0 || task->pid >= PROC_MAX_TASKS)
        return;
    clear_signal(&signals[task->pid]);
    task->signal = &signals[task->pid];
    task->sighand = task->signal;
}

void signal_copy_task(struct task_struct *child,
                      const struct task_struct *parent, int share)
{
    if (!child || !parent || !parent->signal)
        return;
    if (share) {
        child->signal = parent->signal;
        child->sighand = parent->sighand;
    } else {
        signals[child->pid] = *parent->signal;
        signals[child->pid].pending = 0;
        child->signal = &signals[child->pid];
        child->sighand = child->signal;
    }
}

void signal_exec_reset(struct task_struct *task)
{
    uint32_t pending;
    uint32_t blocked;
    if (!task || !task->signal)
        return;
    pending = task->signal->pending;
    blocked = task->signal->blocked;
    clear_signal(task->signal);
    task->signal->pending = pending;
    task->signal->blocked = blocked;
}

int send_sig(int sig, struct task_struct *task)
{
    if (!task || !task->signal || sig < 1 || sig > NSIG ||
        task->state == TASK_DEAD || task->state == TASK_ZOMBIE)
        return -1;
    task->signal->pending |= 1U << (uint32_t)sig;
    if (task->state == TASK_INTERRUPTIBLE || sig == SIGKILL)
        wake_up_process(task);
    return 0;
}

int send_signal(pid_t pid, int sig)
{
    return send_sig(sig, find_task_by_pid(pid));
}

int kill_pid(pid_t pid, int sig)
{
    return send_signal(pid, sig);
}

int signal_pending(const struct task_struct *task)
{
    return task && task->signal &&
        (task->signal->pending & ~task->signal->blocked);
}

int do_sigaction(int sig, const struct k_sigaction *action,
                 struct k_sigaction *old)
{
    if (!current || !current->signal || sig < 1 || sig > NSIG ||
        sig == SIGKILL)
        return -1;
    if (old)
        *old = current->signal->action[sig];
    if (action)
        current->signal->action[sig] = *action;
    return 0;
}

static void default_action(context_t *frame, int sig)
{
    if (sig == SIGTERM || sig == SIGKILL || sig == SIGSEGV) {
        printk("[SIG] pid=%d killed by signal %d\r\n",
               current ? current->pid : -1, sig);
        do_exit(sig, frame);
    }
}

void sig_deliver(context_t *frame)
{
    struct signal_struct *signal;
    uint32_t deliverable;
    int sig;
    sig_handler_t handler;
    uintptr_t stack;
    sig_frame_t *signal_frame;

    if (!current || !frame || !current->signal)
        return;
    signal = current->signal;
    deliverable = signal->pending & ~signal->blocked;
    if (!deliverable)
        return;
    for (sig = 1; sig <= NSIG; ++sig)
        if (deliverable & (1U << (uint32_t)sig))
            break;
    if (sig > NSIG)
        return;
    signal->pending &= ~(1U << (uint32_t)sig);
    handler = signal->action[sig].handler;
    if (sig == SIGKILL || handler == SIG_DFL) {
        default_action(frame, sig);
        return;
    }
    if (handler == SIG_IGN)
        return;

    stack = (frame->r2 - sizeof(*signal_frame)) & ~(uintptr_t)15;
    signal_frame = (sig_frame_t *)stack;
    signal_frame->saved_context = *frame;
    signal_frame->signum = (uint32_t)sig;
    signal_frame->magic = SIG_FRAME_MAGIC;
    frame->r2 = stack;
    frame->r10 = (uintptr_t)sig;
    frame->r1 = (uintptr_t)_sigreturn_trampoline;
    frame->sepc = (uintptr_t)handler;
    signal->blocked |= (1U << (uint32_t)sig) | signal->action[sig].mask;
}

void sig_return(context_t *frame)
{
    sig_frame_t *signal_frame;
    int sig;
    if (!current || !frame)
        return;
    signal_frame = (sig_frame_t *)(uintptr_t)frame->r2;
    if (signal_frame->magic != SIG_FRAME_MAGIC) {
        do_exit(-1, frame);
        return;
    }
    sig = (int)signal_frame->signum;
    *frame = signal_frame->saved_context;
    current->signal->blocked &= ~(1U << (uint32_t)sig);
}
