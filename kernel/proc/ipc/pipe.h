#ifndef DMCTP_PROC_PIPE_H
#define DMCTP_PROC_PIPE_H

#include <stddef.h>
#include <stdint.h>
#include "../../sync/spinlock.h"
#include "../../fs/file.h"

#define PROC_PIPE_SIZE 4096
#define PROC_MAX_PIPES 16

struct proc_pipe {
    spinlock_t lock;
    uint8_t data[PROC_PIPE_SIZE];
    size_t head;
    size_t tail;
    size_t count;
    uint32_t readers;
    uint32_t writers;
    uint32_t used;
};

void pipe_init(void);
struct proc_pipe *pipe_alloc(void);
void pipe_get_reader(struct proc_pipe *pipe);
void pipe_get_writer(struct proc_pipe *pipe);
void pipe_put_reader(struct proc_pipe *pipe);
void pipe_put_writer(struct proc_pipe *pipe);
long pipe_read(struct proc_pipe *pipe, void *buffer, size_t count);
long pipe_write(struct proc_pipe *pipe, const void *buffer, size_t count);
int pipe_create(int *read_fd, int *write_fd);

#endif
