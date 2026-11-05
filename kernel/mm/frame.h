#ifndef MM_FRAME_H
#define MM_FRAME_H

#include <stdint.h>

void frame_alloc_init(void);
int frame_alloc(void);
void frame_free(int ppn);
void frame_stats(uint32_t *total, uint32_t *free_count);

uintptr_t backing_alloc(void);
void backing_free(uintptr_t pa);

#endif
