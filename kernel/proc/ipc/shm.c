#include "shm.h"

static struct shm_segment segments[PROC_MAX_SHM];
static spinlock_t shm_table_lock = { SPINLOCK_UNLOCKED };
static void *(*shm_alloc)(size_t);
static void (*shm_release)(void *);

void shm_init(void *(*alloc)(size_t), void (*release)(void *))
{
    uint32_t i;
    shm_alloc = alloc;
    shm_release = release;
    for (i = 0; i < PROC_MAX_SHM; ++i) {
        segments[i].used = 0;
        segments[i].id = (int)i + 1;
        segments[i].lock.lock = SPINLOCK_UNLOCKED;
    }
}

static struct shm_segment *find_id(int id)
{
    if (id <= 0 || id > PROC_MAX_SHM || !segments[id - 1].used)
        return 0;
    return &segments[id - 1];
}

int shmget(int key, size_t size, int flags)
{
    uint32_t i;
    struct shm_segment *free_slot = 0;
    if (!size || !shm_alloc)
        return -1;
    spin_lock(&shm_table_lock);
    for (i = 0; i < PROC_MAX_SHM; ++i) {
        if (!segments[i].used) {
            if (!free_slot) free_slot = &segments[i];
            continue;
        }
        if (key != IPC_PRIVATE && segments[i].key == key) {
            int id = segments[i].id;
            if ((flags & IPC_CREAT) && (flags & IPC_EXCL))
                id = -1;
            spin_unlock(&shm_table_lock);
            return id;
        }
    }
    if (!(flags & IPC_CREAT) && key != IPC_PRIVATE) {
        spin_unlock(&shm_table_lock);
        return -1;
    }
    if (!free_slot) {
        spin_unlock(&shm_table_lock);
        return -1;
    }
    free_slot->memory = shm_alloc(size);
    if (!free_slot->memory) {
        spin_unlock(&shm_table_lock);
        return -1;
    }
    free_slot->key = key;
    free_slot->size = size;
    free_slot->attachments = 0;
    free_slot->deleted = 0;
    free_slot->used = 1;
    i = (uint32_t)free_slot->id;
    spin_unlock(&shm_table_lock);
    return (int)i;
}

void *shmat(int id)
{
    struct shm_segment *segment = find_id(id);
    void *memory;
    if (!segment || segment->deleted)
        return (void *)-1;
    spin_lock(&segment->lock);
    segment->attachments++;
    memory = segment->memory;
    spin_unlock(&segment->lock);
    return memory;
}

static void destroy_segment(struct shm_segment *segment)
{
    void *memory = segment->memory;
    segment->used = 0;
    segment->memory = 0;
    if (shm_release)
        shm_release(memory);
}

int shmdt(const void *address)
{
    struct shm_segment *segment = 0;
    uint32_t index;
    for (index = 0; index < PROC_MAX_SHM; ++index)
        if (segments[index].used && segments[index].memory == address) {
            segment = &segments[index];
            break;
        }
    if (!segment)
        return -1;
    spin_lock(&segment->lock);
    if (!segment->attachments) {
        spin_unlock(&segment->lock);
        return -1;
    }
    segment->attachments--;
    if (segment->deleted && !segment->attachments)
        destroy_segment(segment);
    spin_unlock(&segment->lock);
    return 0;
}

int shmctl(int id, int command)
{
    struct shm_segment *segment = find_id(id);
    if (!segment || command != IPC_RMID)
        return -1;
    spin_lock(&segment->lock);
    segment->deleted = 1;
    if (!segment->attachments)
        destroy_segment(segment);
    spin_unlock(&segment->lock);
    return 0;
}
