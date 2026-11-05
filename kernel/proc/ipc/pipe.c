#include "pipe.h"
#include "../process.h"
#include "../signal/signal.h"
#include "../../lib/printk.h"

static struct proc_pipe pipes[PROC_MAX_PIPES];
static spinlock_t pipe_table_lock = { SPINLOCK_UNLOCKED };

void pipe_init(void)
{
    uint32_t i;
    for (i = 0; i < PROC_MAX_PIPES; ++i) {
        pipes[i].used = 0;
        pipes[i].lock.lock = SPINLOCK_UNLOCKED;
    }
}

struct proc_pipe *pipe_alloc(void)
{
    uint32_t i;
    spin_lock(&pipe_table_lock);
    for (i = 0; i < PROC_MAX_PIPES; ++i) {
        if (pipes[i].used)
            continue;
        pipes[i].used = 1;
        pipes[i].head = pipes[i].tail = pipes[i].count = 0;
        pipes[i].readers = pipes[i].writers = 1;
        spin_unlock(&pipe_table_lock);
        return &pipes[i];
    }
    spin_unlock(&pipe_table_lock);
    return 0;
}

void pipe_get_reader(struct proc_pipe *pipe)
{
    if (!pipe) return;
    spin_lock(&pipe->lock);
    pipe->readers++;
    spin_unlock(&pipe->lock);
}

void pipe_get_writer(struct proc_pipe *pipe)
{
    if (!pipe) return;
    spin_lock(&pipe->lock);
    pipe->writers++;
    spin_unlock(&pipe->lock);
}

static void pipe_maybe_free(struct proc_pipe *pipe)
{
    if (!pipe->readers && !pipe->writers) {
        spin_lock(&pipe_table_lock);
        pipe->used = 0;
        spin_unlock(&pipe_table_lock);
    }
}

void pipe_put_reader(struct proc_pipe *pipe)
{
    if (!pipe) return;
    spin_lock(&pipe->lock);
    if (pipe->readers) pipe->readers--;
    spin_unlock(&pipe->lock);
    pipe_maybe_free(pipe);
}

void pipe_put_writer(struct proc_pipe *pipe)
{
    if (!pipe) return;
    spin_lock(&pipe->lock);
    if (pipe->writers) pipe->writers--;
    spin_unlock(&pipe->lock);
    pipe_maybe_free(pipe);
}

long pipe_read(struct proc_pipe *pipe, void *buffer, size_t count)
{
    uint8_t *out = buffer;
    size_t done = 0;
    if (!pipe || (!buffer && count))
        return -1;
    spin_lock(&pipe->lock);
    while (done < count && pipe->count) {
        out[done++] = pipe->data[pipe->tail];
        pipe->tail = (pipe->tail + 1) % PROC_PIPE_SIZE;
        pipe->count--;
    }
    if (!done && pipe->writers) {
        spin_unlock(&pipe->lock);
        return -2; /* EAGAIN: caller may sleep and retry. */
    }
    spin_unlock(&pipe->lock);
    return (long)done; /* zero is EOF when there are no writers. */
}

long pipe_write(struct proc_pipe *pipe, const void *buffer, size_t count)
{
    const uint8_t *in = buffer;
    size_t done = 0;
    if (!pipe || (!buffer && count))
        return -1;
    spin_lock(&pipe->lock);
    if (!pipe->readers) {
        spin_unlock(&pipe->lock);
        return -3; /* EPIPE: syscall layer should also raise SIGPIPE. */
    }
    while (done < count && pipe->count < PROC_PIPE_SIZE) {
        pipe->data[pipe->head] = in[done++];
        pipe->head = (pipe->head + 1) % PROC_PIPE_SIZE;
        pipe->count++;
    }
    spin_unlock(&pipe->lock);
    return done ? (long)done : -2;
}

static int read_open(vnode_t *node, int flags)
{
    (void)flags;
    pipe_get_reader(node->data);
    return 0;
}

static int read_close(vnode_t *node)
{
    pipe_put_reader(node->data);
    return 0;
}

static int read_data(vnode_t *node, void *buffer, size_t size, uint32_t *pos)
{
    (void)pos;
    return (int)pipe_read(node->data, buffer, size);
}

static int reject_write(vnode_t *node, const void *buffer, size_t size,
                        uint32_t *pos)
{
    (void)node; (void)buffer; (void)size; (void)pos;
    return -1;
}

static int write_open(vnode_t *node, int flags)
{
    (void)flags;
    pipe_get_writer(node->data);
    return 0;
}

static int write_close(vnode_t *node)
{
    pipe_put_writer(node->data);
    return 0;
}

static int reject_read(vnode_t *node, void *buffer, size_t size, uint32_t *pos)
{
    (void)node; (void)buffer; (void)size; (void)pos;
    return -1;
}

static int write_data(vnode_t *node, const void *buffer, size_t size,
                      uint32_t *pos)
{
    long result;
    (void)pos;
    result = pipe_write(node->data, buffer, size);
    if (result == -3 && current)
        send_sig(SIGPIPE, current);
    return (int)result;
}

static int reject_ioctl(vnode_t *node, uint32_t command, void *argument)
{
    (void)node; (void)command; (void)argument;
    return -1;
}

static vnode_ops_t pipe_read_ops = {
    .open = read_open, .close = read_close, .read = read_data,
    .write = reject_write, .ioctl = reject_ioctl
};

static vnode_ops_t pipe_write_ops = {
    .open = write_open, .close = write_close, .read = reject_read,
    .write = write_data, .ioctl = reject_ioctl
};

int pipe_create(int *read_fd, int *write_fd)
{
    struct proc_pipe *pipe;
    vnode_t *read_node;
    vnode_t *write_node;
    if (!current || !read_fd || !write_fd)
        return -1;
    pipe = pipe_alloc();
    if (!pipe)
        return -1;
    read_node = vnode_alloc(VNODE_PIPE, &pipe_read_ops, pipe);
    write_node = vnode_alloc(VNODE_PIPE, &pipe_write_ops, pipe);
    if (!read_node || !write_node)
        return -1;
    *read_fd = fd_alloc(current->files, read_node, O_RDONLY);
    *write_fd = fd_alloc(current->files, write_node, O_WRONLY);
    if (*read_fd < 0 || *write_fd < 0)
        return -1;
    printk("[PIPE] created rfd=%d wfd=%d\r\n", *read_fd, *write_fd);
    return 0;
}
