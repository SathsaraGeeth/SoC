#ifndef DMCTP_PROC_SIGNAL_H
#define DMCTP_PROC_SIGNAL_H

#include "../sched/sched.h"

#define NSIG 8
#define SIGTERM 1
#define SIGKILL 2
#define SIGCHLD 3
#define SIGSEGV 4
#define SIGPIPE 5
#define SIGUSR1 6
#define SIGUSR2 7

typedef void (*sig_handler_t)(int);
#define SIG_DFL ((sig_handler_t)0)
#define SIG_IGN ((sig_handler_t)1)

struct k_sigaction {
    sig_handler_t handler;
    uint32_t mask;
    uint32_t flags;
};

struct signal_struct {
    uint32_t pending;
    uint32_t blocked;
    struct k_sigaction action[NSIG + 1];
};

typedef struct {
    context_t saved_context;
    uint32_t signum;
    uint32_t magic;
} sig_frame_t;

#define SIG_FRAME_MAGIC 0x516f524d

void signal_init(void);
void signal_init_task(struct task_struct *task);
void signal_copy_task(struct task_struct *child,
                      const struct task_struct *parent, int share);
void signal_exec_reset(struct task_struct *task);
int send_sig(int sig, struct task_struct *task);
int send_signal(pid_t pid, int sig);
int kill_pid(pid_t pid, int sig);
int do_sigaction(int sig, const struct k_sigaction *action,
                 struct k_sigaction *old);
int signal_pending(const struct task_struct *task);
void sig_deliver(context_t *frame);
void sig_return(context_t *frame);

#endif
