#include "frame.h"
#include <soc.h>
#include <stdint.h>
#include "mapping.h" // For PAGE_SIZE

extern char _kernel_bss_end;
#define KERNEL_HEAP_START ((uintptr_t)&_kernel_bss_end)
#define KERNEL_MEM_END    (KERNEL_HEAP_START + KERNEL_HEAP_SIZE)
#define FB_FIRST_FRAME    (FRAMEBUFFER_BASE / PAGE_SIZE)
#define FB_LAST_FRAME     ((FRAMEBUFFER_BASE + FRAMEBUFFER_SIZE + PAGE_SIZE - 1) / PAGE_SIZE)
#define FB1_FIRST_FRAME   (HOST_CONSOLE_BASE / PAGE_SIZE)
#define FB1_LAST_FRAME    ((HOST_CONSOLE_BASE + HOST_CONSOLE_SIZE + PAGE_SIZE - 1) / PAGE_SIZE)

static uint8_t sram_bitmap[1024];

#define BACKING_MAX_PAGES 4096
#define BACKING_START (FS_BASE_BA + FS_SIZE)
static uint8_t backing_bitmap[BACKING_MAX_PAGES / 8];
static int backing_initialized = 0;

void frame_alloc_init(void) {
    int reserved_frames = (KERNEL_MEM_END + PAGE_SIZE - 1) / PAGE_SIZE;
    /* Bug7 fix: clamp to bitmap size; a huge kernel must not make all frames "reserved" */
    if (reserved_frames > 1024) reserved_frames = 1024;
    for (int i = 0; i < reserved_frames; i++) {
        sram_bitmap[i] = 1;
    }
    for (int i = reserved_frames; i < 1024; i++) {
        sram_bitmap[i] = ((i >= FB_FIRST_FRAME && i < FB_LAST_FRAME) ||
                          (i >= FB1_FIRST_FRAME && i < FB1_LAST_FRAME)) ? 1 : 0;
    }
}

int frame_alloc(void) {
    int reserved_frames = (KERNEL_MEM_END + PAGE_SIZE - 1) / PAGE_SIZE;
    for (int i = reserved_frames; i < 1024; i++) {
        if (sram_bitmap[i] == 0) {
            sram_bitmap[i] = 1;
            return i;
        }
    }
    return -1;
}

void frame_free(int ppn) {
    if (ppn >= 0 && ppn < 1024) {
        sram_bitmap[ppn] = 0;
    }
}

void frame_stats(uint32_t *total, uint32_t *free_count) {
    uint32_t available = 0, free_frames = 0;
    int reserved_frames = (KERNEL_MEM_END + PAGE_SIZE - 1) / PAGE_SIZE;
    if (reserved_frames > 1024) reserved_frames = 1024;
    for (int i = reserved_frames; i < 1024; i++) {
        if ((i >= FB_FIRST_FRAME && i < FB_LAST_FRAME) ||
            (i >= FB1_FIRST_FRAME && i < FB1_LAST_FRAME)) continue;
        available++;
        if (!sram_bitmap[i]) free_frames++;
    }
    if (total) *total = available;
    if (free_count) *free_count = free_frames;
}

uintptr_t backing_alloc(void) {
    if (!backing_initialized) {
        for (int i = 0; i < BACKING_MAX_PAGES / 8; i++) backing_bitmap[i] = 0;
        backing_initialized = 1;
    }
    for (int i = 0; i < BACKING_MAX_PAGES; i++) {
        if (!(backing_bitmap[i / 8] & (1 << (i % 8)))) {
            backing_bitmap[i / 8] |= (1 << (i % 8));
            return BACKING_START + i * PAGE_SIZE;
        }
    }
    return 0; // OOM
}

void backing_free(uintptr_t pa) {
    const uintptr_t backing_end =
        BACKING_START + (uintptr_t)BACKING_MAX_PAGES * PAGE_SIZE;
    if (pa < BACKING_START || pa >= backing_end ||
        ((pa - BACKING_START) & (PAGE_SIZE - 1)) != 0) return;

    uintptr_t idx = (pa - BACKING_START) / PAGE_SIZE;
    backing_bitmap[idx / 8] &= (uint8_t)~(1u << (idx % 8));
}
