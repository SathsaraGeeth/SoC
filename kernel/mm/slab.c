#include "slab.h"
#include <stdint.h>

extern void uart_puts(const char *);

/*
 * Simple free-list slab allocator.
 * Memory split into fixed blocks of BLOCK_SIZE.
 * Each block has a header: next pointer + used flag.
 * kmalloc finds first free block that fits.
 * kfree marks block free and merges adjacent free blocks.
 */

#define BLOCK_SIZE   64      /* minimum allocation unit */
#define ALIGN(x)     (((x) + (BLOCK_SIZE-1)) & ~(BLOCK_SIZE-1))

typedef struct block_hdr {
    struct block_hdr *next;  /* next block in list */
    uint32_t          size;  /* usable bytes in this block */
    uint32_t          used;  /* 1=allocated 0=free */
} block_hdr_t;

static block_hdr_t *free_list = NULL;

void slab_init(uint32_t start, uint32_t size) {
    start = ALIGN(start);
    size = size & ~(BLOCK_SIZE-1);
    
    free_list = (block_hdr_t *)start;
    free_list->next = NULL;
    free_list->size = size - sizeof(block_hdr_t);
    free_list->used = 0;
}

void *kmalloc(size_t size) {
    size = ALIGN(size);
    block_hdr_t *cur = free_list;
    block_hdr_t *prev = NULL;

    while (cur) {
        if (!cur->used && cur->size >= size) {
            // Can we split the block?
            if (cur->size >= size + sizeof(block_hdr_t) + BLOCK_SIZE) {
                block_hdr_t *new_blk = (block_hdr_t *)((uint8_t *)cur + sizeof(block_hdr_t) + size);
                new_blk->size = cur->size - size - sizeof(block_hdr_t);
                new_blk->used = 0;
                new_blk->next = cur->next;
                
                cur->size = size;
                cur->next = new_blk;
            }
            cur->used = 1;
            
            uint8_t *ret = (uint8_t *)cur + sizeof(block_hdr_t);
            return (void *)ret;
        }
        prev = cur;
        cur = cur->next;
    }
    return NULL; // Out of memory
}

void kfree(void *ptr) {
    if (!ptr) return;
    
    block_hdr_t *blk = (block_hdr_t *)((uint8_t *)ptr - sizeof(block_hdr_t));
    blk->used = 0;
    
    // Merge adjacent free blocks
    block_hdr_t *cur = free_list;
    while (cur && cur->next) {
        if (!cur->used && !cur->next->used && 
            ((uint8_t *)cur + sizeof(block_hdr_t) + cur->size == (uint8_t *)cur->next)) {
            cur->size += sizeof(block_hdr_t) + cur->next->size;
            cur->next = cur->next->next;
        } else {
            cur = cur->next;
        }
    }
}
