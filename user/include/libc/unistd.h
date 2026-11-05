#ifndef DMCTP_UNISTD_H
#define DMCTP_UNISTD_H

#include <sys/types.h>
#include <fcntl.h>
#include <sys/dmctp.h>
#include <stdio.h>

void exit(int status);
int fork(void);
int exec(const char *path);
pid_t wait(int *status);
pid_t waitpid(pid_t pid, int *status);
pid_t getpid(void);
pid_t getppid(void);
int yield(void);
int pipe(int fds[2]);
int dup2(int oldfd, int newfd);
int kill(pid_t pid, int signal);
int procinfo(unsigned index, dmctp_procinfo_t *info);
void sleep(unsigned seconds);

int open(const char *path, int flags);
int close(int fd);
ssize_t read(int fd, void *buf, size_t n);
ssize_t write(int fd, const void *buf, size_t n);
int ioctl(int fd, unsigned long request, void *arg);
void *mmap(void *addr, size_t length, int prot, int flags, int fd, unsigned offset);
int munmap(void *addr, size_t length);

int readdir(const char *path, unsigned index, dmctp_dirent_t *entry);
int sysinfo(dmctp_sysinfo_t *info);
int mkdir(const char *path);
int unlink(const char *path);
int stat(const char *path, unsigned *size);
int rename(const char *old_path, const char *new_path);
pid_t spawn(const char *path);
int chdir(const char *path);
char *getcwd(char *buf, size_t size);

unsigned long long get_time(void);

#endif
