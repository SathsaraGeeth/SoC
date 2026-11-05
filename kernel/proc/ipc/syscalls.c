#include <syscall/syscall.h>
#include <proc/ipc/pipe.h>
#include <proc/ipc/shm.h>

int64_t sys_pipe_create(struct trap_frame *frame)
{
    int read_fd;
    int write_fd;
    if (pipe_create(&read_fd, &write_fd) < 0)
        return -1;
    frame->r11 = (uintptr_t)write_fd;
    return read_fd;
}

int64_t sys_shm_create(struct trap_frame *frame)
{
    return shmget((int)syscall_arg(frame, 0), syscall_arg(frame, 1),
                  IPC_CREAT);
}

int64_t sys_shm_attach(struct trap_frame *frame)
{
    return (int64_t)(uintptr_t)shmat((int)syscall_arg(frame, 0));
}

int64_t sys_shm_detach(struct trap_frame *frame)
{
    return shmdt((void *)syscall_arg(frame, 0));
}

int64_t sys_shm_remove(struct trap_frame *frame)
{
    return shmctl((int)syscall_arg(frame, 0), IPC_RMID);
}

int64_t sys_msg_create(struct trap_frame *frame) { (void)frame; return -1; }
int64_t sys_msg_send(struct trap_frame *frame) { (void)frame; return -1; }
int64_t sys_msg_recv(struct trap_frame *frame) { (void)frame; return -1; }
