#ifndef DMCTP_SYS_SYSCALL_H
#define DMCTP_SYS_SYSCALL_H

#define SYSCALL_ID(group, subgroup, call) \
    (((group) << 12) | ((subgroup) << 8) | (call))

#define SYS_EXIT            SYSCALL_ID(0,0,0)
#define SYS_FORK            SYSCALL_ID(0,1,0)
#define SYS_EXEC            SYSCALL_ID(0,1,2)
#define SYS_WAIT            SYSCALL_ID(0,1,3)
#define SYS_WAITPID         SYSCALL_ID(0,1,4)
#define SYS_CLONE           SYSCALL_ID(0,2,0)
#define SYS_THREAD_JOIN     SYSCALL_ID(0,2,1)
#define SYS_GETPID          SYSCALL_ID(0,3,0)
#define SYS_GETPPID         SYSCALL_ID(0,3,1)
#define SYS_PROCINFO        SYSCALL_ID(0,3,3)
#define SYS_YIELD           SYSCALL_ID(0,4,0)

#define SYS_OPEN            SYSCALL_ID(1,0,0)
#define SYS_CLOSE           SYSCALL_ID(1,0,1)
#define SYS_DUP2            SYSCALL_ID(1,0,3)
#define SYS_READ            SYSCALL_ID(1,1,0)
#define SYS_WRITE           SYSCALL_ID(1,1,1)
#define SYS_STAT            SYSCALL_ID(1,2,0)
#define SYS_MKDIR           SYSCALL_ID(1,2,2)
#define SYS_UNLINK          SYSCALL_ID(1,2,3)
#define SYS_RENAME          SYSCALL_ID(1,2,4)
#define SYS_READDIR         SYSCALL_ID(1,2,5)
#define SYS_CHDIR           SYSCALL_ID(1,2,6)
#define SYS_GETCWD          SYSCALL_ID(1,2,7)
#define SYS_IOCTL           SYSCALL_ID(1,3,0)

#define SYS_MMAP            SYSCALL_ID(2,0,0)
#define SYS_MUNMAP          SYSCALL_ID(2,0,1)
#define SYS_SHM_CREATE      SYSCALL_ID(2,2,0)
#define SYS_SHM_ATTACH      SYSCALL_ID(2,2,1)
#define SYS_SHM_DETACH      SYSCALL_ID(2,2,2)
#define SYS_SHM_REMOVE      SYSCALL_ID(2,2,3)

#define SYS_PIPE_CREATE     SYSCALL_ID(3,0,0)

#define SYS_KILL            SYSCALL_ID(4,0,0)
#define SYS_SIGACTION       SYSCALL_ID(4,1,0)
#define SYS_SIGRETURN       SYSCALL_ID(4,1,1)

#define SYS_CLOCK_GETTIME   SYSCALL_ID(5,0,0)
#define SYS_SYSINFO         SYSCALL_ID(8,0,2)

#endif
