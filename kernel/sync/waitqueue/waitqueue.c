#include "waitqueue.h"

void waitqueue_init(waitqueue_head_t *queue) {
    spinlock_init(&queue->lock);
    queue->head = NULL;
}

void waitqueue_add(waitqueue_head_t *queue, waitqueue_entry_t *entry) {
    spinlock_lock(&queue->lock);
    entry->next = queue->head;
    queue->head = entry;
    spinlock_unlock(&queue->lock);
}

void waitqueue_remove(waitqueue_head_t *queue, waitqueue_entry_t *entry) {
    waitqueue_entry_t **ptr;
    spinlock_lock(&queue->lock);
    ptr = &queue->head;

    while (*ptr) {
        if (*ptr == entry) {
            *ptr = entry->next;
            break;
        }
        ptr = &(*ptr)->next;
    }
    spinlock_unlock(&queue->lock);
}

void wake_up(waitqueue_head_t *queue) {
    wake_up_nr(queue, UINT32_MAX);
}

uint32_t wake_up_nr(waitqueue_head_t *queue, uint32_t count) {
    waitqueue_entry_t *entry;
    uint32_t woken = 0;

    spinlock_lock(&queue->lock);
    entry = queue->head;
    while (entry && woken < count) {
        wake_up_process(entry->task);
        entry = entry->next;
        woken++;
    }
    spinlock_unlock(&queue->lock);
    return woken;
}

void wait_event(waitqueue_head_t *queue, int (*condition)(void *), void *data) {
    waitqueue_entry_t entry;
    entry.task = current;
    entry.next = NULL;

    while (!condition(data)) {
        waitqueue_add(queue, &entry);
        if (condition(data)) {
            waitqueue_remove(queue, &entry);
            break;
        }
        set_current_state(TASK_UNINTERRUPTIBLE);
        schedule();
        __set_current_state(TASK_RUNNING);
        waitqueue_remove(queue, &entry);
    }
}
