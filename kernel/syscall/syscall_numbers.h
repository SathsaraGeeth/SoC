/*
 * kernel/syscall/syscall_numbers.h
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
 * 1. This is a frozen file, you can append but can not modify existing entries
 * 2. syscall number: |group(4b)|subgroup(4b)|call(8b)|
 */

#ifndef SYSCALL_NUMBERS_H
#define SYSCALL_NUMBERS_H

#define SYSCALL_GROUP_SHIFT     12
#define SYSCALL_SUBGROUP_SHIFT  8


#define SYSCALL_ID(group, subgroup, call)  (((group) << 12) | ((subgroup) << 8) | (call))

/*
 * Process management
 */
#define SYS_EXIT                SYSCALL_ID(0,0,0)
#define SYS_EXIT_GROUP          SYSCALL_ID(0,0,1)
/* process creation */
#define SYS_FORK                SYSCALL_ID(0,1,0)
#define SYS_VFORK               SYSCALL_ID(0,1,1)
#define SYS_EXEC                SYSCALL_ID(0,1,2)
#define SYS_WAIT                SYSCALL_ID(0,1,3)
#define SYS_WAITPID             SYSCALL_ID(0,1,4)
/* threads */
#define SYS_CLONE               SYSCALL_ID(0,2,0)
#define SYS_THREAD_JOIN         SYSCALL_ID(0,2,1)
/* identity */
#define SYS_GETPID              SYSCALL_ID(0,3,0)
#define SYS_GETPPID             SYSCALL_ID(0,3,1)
#define SYS_GETTID              SYSCALL_ID(0,3,2)
#define SYS_PROCINFO            SYSCALL_ID(0,3,3)   // procfs
/* scheduling */
#define SYS_YIELD               SYSCALL_ID(0,4,0)
#define SYS_SET_PRIORITY        SYSCALL_ID(0,4,1)
#define SYS_GET_PRIORITY        SYSCALL_ID(0,4,2)


/*
 * Filesystem and Virtual File System
 */
/* file descriptor */
#define SYS_OPEN                SYSCALL_ID(1,0,0)
#define SYS_CLOSE               SYSCALL_ID(1,0,1)
#define SYS_DUP                 SYSCALL_ID(1,0,2)
#define SYS_DUP2                SYSCALL_ID(1,0,3)
/* IO */
#define SYS_READ                SYSCALL_ID(1,1,0)
#define SYS_WRITE               SYSCALL_ID(1,1,1)
#define SYS_PREAD               SYSCALL_ID(1,1,2)
#define SYS_PWRITE              SYSCALL_ID(1,1,3)
/* filesystem namespace */
#define SYS_STAT                SYSCALL_ID(1,2,0)
#define SYS_FSTAT               SYSCALL_ID(1,2,1)
#define SYS_MKDIR               SYSCALL_ID(1,2,2)
#define SYS_UNLINK              SYSCALL_ID(1,2,3)
#define SYS_RENAME              SYSCALL_ID(1,2,4)
#define SYS_READDIR             SYSCALL_ID(1,2,5)
#define SYS_CHDIR               SYSCALL_ID(1,2,6)
#define SYS_GETCWD              SYSCALL_ID(1,2,7)
/* devices */
#define SYS_IOCTL               SYSCALL_ID(1,3,0)


/*
 * Memory Management
 */
/* virtual memory */
#define SYS_MMAP                SYSCALL_ID(2,0,0)
#define SYS_MUNMAP              SYSCALL_ID(2,0,1)
#define SYS_MPROTECT            SYSCALL_ID(2,0,2)
/* heap */
#define SYS_BRK                 SYSCALL_ID(2,1,0)
/* shared memory */
#define SYS_SHM_CREATE          SYSCALL_ID(2,2,0)
#define SYS_SHM_ATTACH          SYSCALL_ID(2,2,1)
#define SYS_SHM_DETACH          SYSCALL_ID(2,2,2)
#define SYS_SHM_REMOVE          SYSCALL_ID(2,2,3)


/*
 * Inter Process Communication
 */
/* pipes */
#define SYS_PIPE_CREATE         SYSCALL_ID(3,0,0)
/* message queues */
#define SYS_MSG_CREATE          SYSCALL_ID(3,1,0)
#define SYS_MSG_SEND            SYSCALL_ID(3,1,1)
#define SYS_MSG_RECV            SYSCALL_ID(3,1,2)


/*
 * Signals
 */
/* signal delivery */
#define SYS_KILL                SYSCALL_ID(4,0,0)
/* signal handlers */
#define SYS_SIGACTION           SYSCALL_ID(4,1,0)
#define SYS_SIGRETURN           SYSCALL_ID(4,1,1)
/* signal masks */
#define SYS_SIGPROCMASK         SYSCALL_ID(4,2,0)


/*
 * Time and Timers
 */
/* clocks */
#define SYS_CLOCK_GETTIME       SYSCALL_ID(5,0,0)
/* sleeping */
#define SYS_NANOSLEEP           SYSCALL_ID(5,1,0)
/* timers */
#define SYS_TIMER_CREATE        SYSCALL_ID(5,2,0)
#define SYS_TIMER_DELETE        SYSCALL_ID(5,2,1)


/*
 * Synchronization
 */
/* futex */
#define SYS_FUTEX               SYSCALL_ID(6,0,0)
/* locks */
#define SYS_MUTEX_CREATE        SYSCALL_ID(6,1,0)
/* semaphores */
#define SYS_SEMAPHORE_CREATE    SYSCALL_ID(6,2,0)


/*
 * Networking
 */
/* socket lifecycle */
#define SYS_SOCKET              SYSCALL_ID(7,0,0)
#define SYS_BIND                SYSCALL_ID(7,0,1)
#define SYS_LISTEN              SYSCALL_ID(7,0,2)
#define SYS_ACCEPT              SYSCALL_ID(7,0,3)
/* communication */
#define SYS_CONNECT             SYSCALL_ID(7,1,0)
#define SYS_SEND                SYSCALL_ID(7,1,1)
#define SYS_RECV                SYSCALL_ID(7,1,2)


/*
 * System and Hardware
 */
/* system information */
#define SYS_UNAME               SYSCALL_ID(8,0,0)
#define SYS_GETCPU              SYSCALL_ID(8,0,1)
#define SYS_SYSINFO             SYSCALL_ID(8,0,2)
/* randomness */
#define SYS_GETRANDOM           SYSCALL_ID(8,1,0)

#endif /* SYSCALL_NUMBERS_H */
