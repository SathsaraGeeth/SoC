/*
 * Comments:
 * 1. Bump allocator
 * 2. No free, at least for now
 */

#include "heap.h"
#include <stdint.h>
#include <console_early.h>
#include <soc.h>
#include <regs.h>


static uint32_t heap_base  = 0;
static uint32_t heap_top   = 0;
static uint32_t heap_end   = 0;

void heap_init(uint32_t start, uint32_t size) {
    heap_base = (start + ARCH_WORD_SIZE - 1) & ~(ARCH_WORD_SIZE - 1); /* align */
    heap_top  = heap_base;
    heap_end  = heap_base + size;
}

void *kmalloc(size_t size) {
    size     = (size + ARCH_WORD_SIZE - 1) & ~(ARCH_WORD_SIZE - 1);     /* align */
    heap_top = (heap_top + ARCH_WORD_SIZE - 1) & ~(ARCH_WORD_SIZE - 1); /* align */

    if (size > (heap_end - heap_top)){
        uint32_t tid = csr_read(CSR_THREAD_ID);
        console_early_puts("[MM] heap out of memory\r\n");
        while (1) { 
            wfi();
        }
    }

    void *ptr = (void *)heap_top;
    heap_top += size;
    return ptr;
}
