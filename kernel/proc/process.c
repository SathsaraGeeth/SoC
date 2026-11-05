#include "process.h"
#include "exec/exec.h"
#include "exit/exit.h"
#include "fork/fork.h"
#include "sched/pid.h"
#include "signal/signal.h"
#include "../drivers/core/dev.h"
#include "../fs/vfs.h"
#include "../mm/slab.h"
#include "../lib/printk.h"
#include <regs.h>
#include <soc.h>

struct task_resources {
    mm_t mm;
    fd_table_t files;
    uint32_t mm_users;
    uint32_t files_users;
};

static struct task_resources resources[PROC_MAX_TASKS];
static struct task_struct *deferred_reap[PROC_MAX_TASKS];
static volatile uint32_t deferred_reap_pending;
static spinlock_t reap_lock = { SPINLOCK_UNLOCKED };

extern void proc_enter_user(const context_t *, uintptr_t);

static void zero_memory(void *pointer, size_t size)
{
    unsigned char *byte = pointer;
    while (size--)
        *byte++ = 0;
}

static void copy_name(char *destination, const char *source)
{
    uint32_t index = 0;
    while (source && source[index] && index + 1 < PROC_TASK_NAME_LEN) {
        destination[index] = source[index];
        ++index;
    }
    destination[index] = '\0';
}

mm_t *task_mm(struct task_struct *task)
{
    return task ? task->mm : 0;
}

fd_table_t *task_files(struct task_struct *task)
{
    return task ? task->files : 0;
}

static void setup_stdio(struct task_struct *task)
{
    vnode_t *uart = dev_find("uart0");
    uint32_t fd;
    if (!uart)
        return;
    for (fd = 0; fd < 3; ++fd) {
        uart->refcount++;
        task->files->files[fd].vnode = uart;
        task->files->files[fd].flags = fd ? O_WRONLY : O_RDONLY;
        task->files->files[fd].pos = 0;
        task->files->files[fd].used = 1;
    }
}

void process_init(void)
{
    uint32_t index;
    task_model_init(THREADS_IN_CLUSTER);
    for (index = 0; index < PROC_MAX_TASKS; ++index)
    {
        zero_memory(&resources[index], sizeof(resources[index]));
        deferred_reap[index] = 0;
    }
    printk("[PROC] Task model initialized\r\n");
}

struct task_struct *process_create(void (*entry)(void), const char *name,
                                   struct task_struct *parent)
{
    struct task_struct *task = task_alloc();
    uintptr_t stack_top;
    if (!task)
        return 0;
    task->parent = parent;
    task->mm = &resources[task->pid].mm;
    task->active_mm = task->mm;
    task->files = &resources[task->pid].files;
    task->mm->asid = (uintptr_t)task->pid & 0xff;
    resources[task->pid].mm_users = 1;
    resources[task->pid].files_users = 1;
    fd_table_init(task->files);
    task->fs.cwd_inode = parent ? parent->fs.cwd_inode : vfs_root();
    task->stack = kmalloc(PROC_STACK_SIZE);
    if (!task->stack) {
        task_release(task);
        return 0;
    }
    stack_top = (uintptr_t)task->stack + PROC_STACK_SIZE;
    zero_memory(&task->context, sizeof(task->context));
    task->context.r1 = (uintptr_t)entry;
    task->context.r2 = stack_top;
    task->context.sepc = (uintptr_t)entry;
    task->context.sstatus = csr_read(CSR_SSTATUS) | SSTATUS_SPP_S | SSTATUS_SPIE;
    copy_name(task->comm, name ? name : "task");
    if (parent)
        list_add_tail(&task->sibling, &parent->children);
    else
        setup_stdio(task);
    return task;
}

static struct task_resources *resource_for_mm(mm_t *mm)
{
    uint32_t index;
    for (index = 0; index < PROC_MAX_TASKS; ++index)
        if (&resources[index].mm == mm)
            return &resources[index];
    return 0;
}

static struct task_resources *resource_for_files(fd_table_t *files)
{
    uint32_t index;
    for (index = 0; index < PROC_MAX_TASKS; ++index)
        if (&resources[index].files == files)
            return &resources[index];
    return 0;
}

int process_copy_mm(struct task_struct *child, struct task_struct *parent,
                    int share)
{
    uint32_t index;
    if (share) {
        struct task_resources *owner = resource_for_mm(parent->mm);
        if (!owner) return -1;
        owner->mm_users++;
        child->mm = parent->mm;
        child->active_mm = parent->active_mm;
        return 0;
    }
    child->mm->asid = (uintptr_t)child->pid & 0xff;
    child->mm->page_map = 0;
    for (index = 0; index < MAX_VMAS; ++index)
        if (parent->mm->vmas[index].used)
            mapping_fork_vma(parent->mm, child->mm,
                             &parent->mm->vmas[index]);
    return 0;
}

void process_copy_files(struct task_struct *child, struct task_struct *parent,
                        int share)
{
    if (share) {
        struct task_resources *owner = resource_for_files(parent->files);
        if (owner) owner->files_users++;
        child->files = parent->files;
    } else {
        fd_table_copy(child->files, parent->files);
    }
}

void process_release_resources(struct task_struct *task)
{
    struct task_resources *mm_owner;
    struct task_resources *files_owner;
    int index;
    if (!task) return;
    files_owner = resource_for_files(task->files);
    if (files_owner && files_owner->files_users &&
        --files_owner->files_users == 0)
        for (index = 0; index < MAX_FDS; ++index)
            fd_free(task->files, index);
    mm_owner = resource_for_mm(task->mm);
    if (mm_owner && mm_owner->mm_users && --mm_owner->mm_users == 0)
        for (index = 0; index < MAX_VMAS; ++index)
            if (task->mm->vmas[index].used) {
                mapping_free_vma(task->mm, &task->mm->vmas[index]);
                task->mm->vmas[index].used = 0;
            }
    /* The active trap frame lives on task->stack.  Stack reclamation must be
     * deferred until a later task is executing; never free it in do_exit(). */
}

void process_reap_task(struct task_struct *task)
{
    if (!task)
        return;
    if (task->stack) {
        kfree(task->stack);
        task->stack = 0;
    }
    task_release(task);
}

void process_defer_reap(struct task_struct *task)
{
    uint32_t index;
    if (!task)
        return;
    spin_lock(&reap_lock);
    for (index = 0; index < PROC_MAX_TASKS; ++index)
        if (!deferred_reap[index]) {
            deferred_reap[index] = task;
            task->state = TASK_DEAD;
            __atomic_store_n(&deferred_reap_pending, 1u, __ATOMIC_RELEASE);
            break;
        }
    spin_unlock(&reap_lock);
}

void process_reap_deferred(void)
{
    uint32_t index;
    struct task_struct *pending[PROC_MAX_TASKS];

    if (!__atomic_load_n(&deferred_reap_pending, __ATOMIC_ACQUIRE))
        return;
    if (!spinlock_trylock(&reap_lock))
        return;
    for (index = 0; index < PROC_MAX_TASKS; ++index) {
        pending[index] = deferred_reap[index];
        deferred_reap[index] = 0;
    }
    __atomic_store_n(&deferred_reap_pending, 0u, __ATOMIC_RELEASE);
    spin_unlock(&reap_lock);

    for (index = 0; index < PROC_MAX_TASKS; ++index) {
        struct task_struct *task = pending[index];
        if (task && task != current)
            process_reap_task(task);
    }
}

pid_t process_spawn(void (*entry)(void), const char *name)
{
    struct task_struct *task = process_create(entry, name, current);
    if (!task)
        return -1;
    if (current)
        fd_table_copy(task->files, current->files);
    sched_enqueue(task);
    return task->pid;
}

static void spawned_user_entry(void)
{
    if (do_exec(&current->context, current->exec_path) < 0)
        do_exit(-1, &current->context);
    csr_write(CSR_VIRTUAL_THRD_ID, current->mm->asid & 0xff);
    process_enter_user(&current->context,
                       (uintptr_t)current->stack + PROC_STACK_SIZE);
}

pid_t process_spawn_user(const char *path)
{
    struct task_struct *task;
    pid_t pid;
    uint32_t index = 0;
    if (!current || !path || !*path)
        return -1;
    task = process_create(spawned_user_entry, path, current);
    if (!task)
        return -1;
    fd_table_copy(task->files, current->files);
    while (path[index] && index + 1 < sizeof(task->exec_path)) {
        task->exec_path[index] = path[index];
        ++index;
    }
    task->exec_path[index] = '\0';
    pid = task->pid;
    sched_enqueue(task);
    return pid;
}

pid_t process_thread_create(uintptr_t entry, uintptr_t arg,
                            uintptr_t user_stack, uintptr_t return_pc)
{
    pid_t pid = do_clone(CLONE_VM | CLONE_FILES | CLONE_SIGHAND |
                         CLONE_THREAD, 0);
    struct task_struct *thread = find_task_by_pid(pid);
    if (!thread)
        return -1;
    zero_memory(&thread->context, sizeof(thread->context));
    thread->context.r1 = return_pc;
    thread->context.r2 = user_stack & ~(uintptr_t)15;
    thread->context.r10 = arg;
    thread->context.sepc = entry;
    thread->context.sstatus = SSTATUS_SPP_U | SSTATUS_SPIE;
    thread->is_thread = 1;
    sched_enqueue(thread);
    return pid;
}

void process_finish_switch(struct task_struct *next)
{
    uintptr_t kernel_sp = (next->context.sstatus & SSTATUS_SPP_S) ? 0 :
        (uintptr_t)next->stack + PROC_STACK_SIZE;
    /* Per-CPU idle contexts are kernel-only and intentionally have no mm. */
    if (next->mm) {
        csr_write(CSR_VIRTUAL_THRD_ID, next->mm->asid & 0xff);
        mapping_activate(next->mm);
    }
    csr_write(CSR_SSCRATCH, kernel_sp);
    if (next->signal)
        sig_deliver(&next->context);
}

void finish_task_switch(struct task_struct *next)
{
    process_finish_switch(next);
}

void process_schedule(context_t *frame)
{
    schedule_from_trap(frame);
}

void process_enter_user(const context_t *frame, uintptr_t kernel_sp)
{
    proc_enter_user(frame, kernel_sp);
    __builtin_unreachable();
}

int process_open(const char *path, int flags)
{
    vnode_t *node;
    int fd;
    if (!current)
        return -1;
    node = vfs_open(path, flags);
    if (!node)
        return -1;
    if (node->type == VNODE_DEV)
        node->refcount++;
    fd = fd_alloc(current->files, node, flags);
    if (fd >= 0 && (flags & O_APPEND)) {
        uint32_t size = 0;
        if (!vfs_stat(path, current->fs.cwd_inode, &size))
            current->files->files[fd].pos = size;
    }
    return fd;
}

int process_close(int fd) { if (!current) return -1; fd_free(current->files, fd); return 0; }
int process_read(int fd, void *buf, size_t size) { file_t *f = current ? fd_get(current->files, fd) : 0; return (!f || !f->vnode || !f->vnode->ops->read) ? -1 : f->vnode->ops->read(f->vnode, buf, size, &f->pos); }
int process_write(int fd, const void *buf, size_t size) { file_t *f = current ? fd_get(current->files, fd) : 0; return (!f || !f->vnode || !f->vnode->ops->write) ? -1 : f->vnode->ops->write(f->vnode, buf, size, &f->pos); }
int process_ioctl(int fd, uint32_t command, void *argument) { file_t *f = current ? fd_get(current->files, fd) : 0; return (!f || !f->vnode || !f->vnode->ops->ioctl) ? -1 : f->vnode->ops->ioctl(f->vnode, command, argument); }

int process_dup2(int oldfd, int newfd)
{
    file_t *old;
    if (!current || oldfd < 0 || oldfd >= MAX_FDS || newfd < 0 || newfd >= MAX_FDS)
        return -1;
    old = fd_get(current->files, oldfd);
    if (!old) return -1;
    if (oldfd == newfd) return newfd;
    if (current->files->files[newfd].used) fd_free(current->files, newfd);
    current->files->files[newfd] = *old;
    if (old->vnode) old->vnode->refcount++;
    return newfd;
}

int process_mkdir(const char *path) { return current ? vfs_mkdir(path, current->fs.cwd_inode) : -1; }
int process_remove(const char *path) { return current ? vfs_rm(path, current->fs.cwd_inode) : -1; }
int process_stat(const char *path, uint32_t *size) { return current ? vfs_stat(path, current->fs.cwd_inode, size) : -1; }
int process_chdir(const char *path) { uint32_t inode; if (!current || vfs_chdir(path, current->fs.cwd_inode, &inode) < 0) return -1; current->fs.cwd_inode = inode; return 0; }
int process_getcwd(char *buffer, int size) { if (!current || !buffer || size < 2) return -1; vfs_getcwd(current->fs.cwd_inode, buffer, size); return 0; }
int process_rename(const char *old_path, const char *new_path) { return current ? vfs_rename(old_path, new_path, current->fs.cwd_inode) : -1; }
