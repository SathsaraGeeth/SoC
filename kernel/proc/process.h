#ifndef DMCTP_PROCESS_H
#define DMCTP_PROCESS_H

#include "sched/sched.h"
#include "../mm/mapping.h"
#include "../fs/file.h"

#define PROC_STACK_SIZE 4096

void process_init(void);
struct task_struct *process_create(void (*entry)(void), const char *name,
                                   struct task_struct *parent);
pid_t process_spawn(void (*entry)(void), const char *name);
pid_t process_spawn_user(const char *path);
pid_t process_thread_create(uintptr_t entry, uintptr_t arg,
                            uintptr_t user_stack, uintptr_t return_pc);
void process_schedule(context_t *frame);
void process_finish_switch(struct task_struct *next);
void process_enter_user(const context_t *frame, uintptr_t kernel_sp)
    __attribute__((noreturn));

mm_t *task_mm(struct task_struct *task);
fd_table_t *task_files(struct task_struct *task);
int process_copy_mm(struct task_struct *child, struct task_struct *parent,
                    int share);
void process_copy_files(struct task_struct *child, struct task_struct *parent,
                        int share);
void process_release_resources(struct task_struct *task);
void process_defer_reap(struct task_struct *task);
void process_reap_deferred(void);
void process_reap_task(struct task_struct *task);

int process_open(const char *path, int flags);
int process_close(int fd);
int process_read(int fd, void *buf, size_t size);
int process_write(int fd, const void *buf, size_t size);
int process_ioctl(int fd, uint32_t command, void *argument);
int process_dup2(int oldfd, int newfd);
int process_mkdir(const char *path);
int process_remove(const char *path);
int process_stat(const char *path, uint32_t *size);
int process_chdir(const char *path);
int process_getcwd(char *buffer, int size);
int process_rename(const char *old_path, const char *new_path);

#endif
