/*
 * kernel/syscall/syscall_table.c
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. here we do not implement syscalls
 *    the implementation should come from the relvent subsystem
 */

#include "syscall.h"
#include "syscall_numbers.h"

#define DECLARE(name) extern int64_t name(struct trap_frame *)

DECLARE(sys_exit);
DECLARE(sys_exit_group);
DECLARE(sys_fork); 
DECLARE(sys_vfork); 
DECLARE(sys_exec);
DECLARE(sys_wait); 
DECLARE(sys_waitpid);
DECLARE(sys_clone); 
DECLARE(sys_thread_join);
DECLARE(sys_getpid); 
DECLARE(sys_getppid); 
DECLARE(sys_gettid);
DECLARE(sys_yield); 
DECLARE(sys_set_priority); 
DECLARE(sys_get_priority);
DECLARE(sys_procinfo);
DECLARE(sys_open); 
DECLARE(sys_close); 
DECLARE(sys_dup); 
DECLARE(sys_dup2);
DECLARE(sys_read); 
DECLARE(sys_write); 
DECLARE(sys_pread); 
DECLARE(sys_pwrite);
DECLARE(sys_stat); 
DECLARE(sys_fstat); 
DECLARE(sys_mkdir);
DECLARE(sys_unlink); 
DECLARE(sys_rename); 
DECLARE(sys_readdir);
DECLARE(sys_chdir); 
DECLARE(sys_getcwd); 
DECLARE(sys_ioctl);
DECLARE(sys_mmap); 
DECLARE(sys_munmap); 
DECLARE(sys_mprotect);
DECLARE(sys_brk);
DECLARE(sys_shm_create); 
DECLARE(sys_shm_attach);
DECLARE(sys_shm_detach); 
DECLARE(sys_shm_remove);
DECLARE(sys_pipe_create); 
DECLARE(sys_msg_create);
DECLARE(sys_msg_send); 
DECLARE(sys_msg_recv);
DECLARE(sys_kill); 
DECLARE(sys_sigaction);
DECLARE(sys_sigreturn); 
DECLARE(sys_sigprocmask);
DECLARE(sys_clock_gettime); 
DECLARE(sys_nanosleep);
DECLARE(sys_timer_create); 
DECLARE(sys_timer_delete);
DECLARE(sys_uname); 
DECLARE(sys_getcpu); 
DECLARE(sys_getrandom);
DECLARE(sys_sysinfo);

#define ENTRY(number, function) {(uint16_t)(number), (function)}

const struct syscall_entry syscall_table[] = {
    ENTRY(SYS_EXIT, sys_exit),
    ENTRY(SYS_EXIT_GROUP, sys_exit_group),
    ENTRY(SYS_FORK, sys_fork),
    ENTRY(SYS_VFORK, sys_vfork),
    ENTRY(SYS_EXEC, sys_exec),
    ENTRY(SYS_WAIT, sys_wait),
    ENTRY(SYS_WAITPID, sys_waitpid),
    ENTRY(SYS_CLONE, sys_clone),
    ENTRY(SYS_THREAD_JOIN, sys_thread_join),
    ENTRY(SYS_GETPID, sys_getpid),
    ENTRY(SYS_GETPPID, sys_getppid),
    ENTRY(SYS_GETTID, sys_gettid),
    ENTRY(SYS_YIELD, sys_yield),
    ENTRY(SYS_SET_PRIORITY, sys_set_priority),
    ENTRY(SYS_GET_PRIORITY, sys_get_priority),
    ENTRY(SYS_PROCINFO, sys_procinfo),
    ENTRY(SYS_OPEN, sys_open),
    ENTRY(SYS_CLOSE, sys_close),
    ENTRY(SYS_DUP, sys_dup),
    ENTRY(SYS_DUP2, sys_dup2),
    ENTRY(SYS_READ, sys_read),
    ENTRY(SYS_WRITE, sys_write),
    ENTRY(SYS_PREAD, sys_pread),
    ENTRY(SYS_PWRITE, sys_pwrite),
    ENTRY(SYS_STAT, sys_stat),
    ENTRY(SYS_FSTAT, sys_fstat),
    ENTRY(SYS_MKDIR, sys_mkdir),
    ENTRY(SYS_UNLINK, sys_unlink),
    ENTRY(SYS_RENAME, sys_rename),
    ENTRY(SYS_READDIR, sys_readdir),
    ENTRY(SYS_CHDIR, sys_chdir),
    ENTRY(SYS_GETCWD, sys_getcwd),
    ENTRY(SYS_IOCTL, sys_ioctl),
    ENTRY(SYS_MMAP, sys_mmap),
    ENTRY(SYS_MUNMAP, sys_munmap),
    ENTRY(SYS_MPROTECT, sys_mprotect),
    ENTRY(SYS_BRK, sys_brk),
    ENTRY(SYS_SHM_CREATE, sys_shm_create),
    ENTRY(SYS_SHM_ATTACH, sys_shm_attach),
    ENTRY(SYS_SHM_DETACH, sys_shm_detach),
    ENTRY(SYS_SHM_REMOVE, sys_shm_remove),
    ENTRY(SYS_PIPE_CREATE, sys_pipe_create),
    ENTRY(SYS_MSG_CREATE, sys_msg_create),
    ENTRY(SYS_MSG_SEND, sys_msg_send),
    ENTRY(SYS_MSG_RECV, sys_msg_recv),
    ENTRY(SYS_KILL, sys_kill),
    ENTRY(SYS_SIGACTION, sys_sigaction),
    ENTRY(SYS_SIGRETURN, sys_sigreturn),
    ENTRY(SYS_SIGPROCMASK, sys_sigprocmask),
    ENTRY(SYS_CLOCK_GETTIME, sys_clock_gettime),
    ENTRY(SYS_NANOSLEEP, sys_nanosleep),
    ENTRY(SYS_TIMER_CREATE, sys_timer_create),
    ENTRY(SYS_TIMER_DELETE, sys_timer_delete),
    ENTRY(SYS_UNAME, sys_uname),
    ENTRY(SYS_GETCPU, sys_getcpu),
    ENTRY(SYS_GETRANDOM, sys_getrandom),
    ENTRY(SYS_SYSINFO, sys_sysinfo)
};

const size_t syscall_table_size = sizeof(syscall_table) / sizeof(syscall_table[0]);
