#ifndef DMCTP_PROC_SHM_H
#define DMCTP_PROC_SHM_H

#include <stddef.h>
#include <stdint.h>
#include "../../sync/spinlock.h"

#define PROC_MAX_SHM 16
#define IPC_PRIVATE 0
#define IPC_CREAT 01000
#define IPC_EXCL 02000
#define IPC_RMID 0

struct shm_segment {
    spinlock_t lock;
    int id;
    int key;
    void *memory;
    size_t size;
    uint32_t attachments;
    uint32_t used;
    uint32_t deleted;
};

void shm_init(void *(*alloc)(size_t), void (*release)(void *));
int shmget(int key, size_t size, int flags);
void *shmat(int id);
int shmdt(const void *address);
int shmctl(int id, int command);

#endif
