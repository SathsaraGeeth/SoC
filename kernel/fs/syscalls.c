#include <syscall/syscall.h>
#include <syscall/usercopy.h>
#include <proc/process.h>
#include <fs/vfs.h>
#include <soc.h>
#include "../../user/include/sys/dmctp.h"

static _Alignas(uintptr_t) uint8_t io_buffer[1024];

int64_t sys_open(struct trap_frame *frame)
{
    char path[128];
    if (copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                              sizeof(path)) < 0)
        return -1;
    return process_open(path, (int)syscall_arg(frame, 1));
}

int64_t sys_close(struct trap_frame *frame)
{
    return process_close((int)syscall_arg(frame, 0));
}

int64_t sys_dup(struct trap_frame *frame)
{
    int oldfd = (int)syscall_arg(frame, 0);
    int newfd;
    for (newfd = 0; newfd < MAX_FDS; ++newfd)
        if (!current->files->files[newfd].used)
            return process_dup2(oldfd, newfd);
    return -1;
}

int64_t sys_dup2(struct trap_frame *frame)
{
    return process_dup2((int)syscall_arg(frame, 0),
                        (int)syscall_arg(frame, 1));
}

int64_t sys_read(struct trap_frame *frame)
{
    int fd = (int)syscall_arg(frame, 0);
    uintptr_t destination = syscall_arg(frame, 1);
    size_t requested = syscall_arg(frame, 2);
    size_t total = 0;
    while (total < requested) {
        size_t chunk = requested - total;
        int count;
        if (chunk > sizeof(io_buffer)) chunk = sizeof(io_buffer);
        count = process_read(fd, io_buffer, chunk);
        if (count < 0) return total ? (int64_t)total : -1;
        if (!count) break;
        if (copy_to_user((void *)(destination + total), io_buffer,
                         (size_t)count) < 0)
            return total ? (int64_t)total : -1;
        total += (size_t)count;
        if ((size_t)count < chunk) break;
    }
    return (int64_t)total;
}

int64_t sys_write(struct trap_frame *frame)
{
    int fd = (int)syscall_arg(frame, 0);
    uintptr_t source = syscall_arg(frame, 1);
    size_t requested = syscall_arg(frame, 2);
    size_t total = 0;
    while (total < requested) {
        size_t chunk = requested - total;
        int count;
        if (chunk > sizeof(io_buffer)) chunk = sizeof(io_buffer);
        if (copy_from_user(io_buffer, (void *)(source + total), chunk) < 0)
            return total ? (int64_t)total : -1;
        count = process_write(fd, io_buffer, chunk);
        if (count < 0) return total ? (int64_t)total : -1;
        total += (size_t)count;
        if ((size_t)count < chunk) break;
    }
    return (int64_t)total;
}

int64_t sys_pread(struct trap_frame *frame) { (void)frame; return -1; }
int64_t sys_pwrite(struct trap_frame *frame) { (void)frame; return -1; }

int64_t sys_stat(struct trap_frame *frame)
{
    char path[128];
    uint32_t size;
    if (copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                              sizeof(path)) < 0 ||
        process_stat(path, &size) < 0)
        return -1;
    return copy_to_user((void *)syscall_arg(frame, 1), &size, sizeof(size));
}

int64_t sys_fstat(struct trap_frame *frame) { (void)frame; return -1; }

int64_t sys_mkdir(struct trap_frame *frame)
{
    char path[128];
    return copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                                 sizeof(path)) < 0 ? -1 : process_mkdir(path);
}

int64_t sys_unlink(struct trap_frame *frame)
{
    char path[128];
    return copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                                 sizeof(path)) < 0 ? -1 : process_remove(path);
}

int64_t sys_rename(struct trap_frame *frame)
{
    char old_path[128], new_path[128];
    if (copy_string_from_user(old_path, (const char *)syscall_arg(frame, 0),
                              sizeof(old_path)) < 0 ||
        copy_string_from_user(new_path, (const char *)syscall_arg(frame, 1),
                              sizeof(new_path)) < 0)
        return -1;
    return process_rename(old_path, new_path);
}

int64_t sys_ioctl(struct trap_frame *frame)
{
    return process_ioctl((int)syscall_arg(frame, 0),
                         (uint32_t)syscall_arg(frame, 1),
                         (void *)syscall_arg(frame, 2));
}

int64_t sys_readdir(struct trap_frame *frame)
{
    char path[128];
    dmctp_dirent_t entry = {0};
    int result;
    if (copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                              sizeof(path)) < 0)
        return -1;
    result = vfs_readdir(path, current->fs.cwd_inode,
                         (uint32_t)syscall_arg(frame, 1), entry.name,
                         &entry.type, &entry.size);
    if (result > 0 &&
        copy_to_user((void *)syscall_arg(frame, 2), &entry, sizeof(entry)) < 0)
        return -1;
    return result;
}

int64_t sys_chdir(struct trap_frame *frame)
{
    char path[128];
    return copy_string_from_user(path, (const char *)syscall_arg(frame, 0),
                                 sizeof(path)) < 0 ? -1 : process_chdir(path);
}

int64_t sys_getcwd(struct trap_frame *frame)
{
    char path[128];
    size_t length = 0;
    if (process_getcwd(path, sizeof(path)) < 0)
        return -1;
    while (path[length]) ++length;
    if (length + 1 > syscall_arg(frame, 1))
        return -1;
    return copy_to_user((void *)syscall_arg(frame, 0), path, length + 1);
}
