#ifndef MM_CLOCK_H
#define MM_CLOCK_H

#include <stdint.h>

struct frame {
    int used;
    uint8_t ref;
    uint8_t dirty;
    uint32_t backing_pa;
};

void clock_init(void);
void clock_record_access(int ppn, uint32_t backing_pa);
void clock_mark_dirty(int ppn);
int clock_is_dirty(int ppn);
int clock_evict(uintptr_t *out_backing_pa);

#endif
