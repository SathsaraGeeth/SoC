#include "clock.h"
#include <stddef.h>

static struct frame frames[1024];
static int clock_hand = 0;

void clock_init(void) {
    for (int i = 0; i < 1024; i++) {
        frames[i].used = 0;
        frames[i].ref = 0;
        frames[i].dirty = 0;
        frames[i].backing_pa = 0;
    }
}

void clock_record_access(int ppn, uint32_t backing_pa) {
    if (ppn >= 0 && ppn < 1024) {
        frames[ppn].used = 1;
        frames[ppn].ref = 1;
        frames[ppn].backing_pa = backing_pa;
    }
}

void clock_mark_dirty(int ppn) {
    if (ppn >= 0 && ppn < 1024) {
        frames[ppn].dirty = 1;
    }
}

int clock_is_dirty(int ppn) {
    if (ppn >= 0 && ppn < 1024) {
        return frames[ppn].dirty;
    }
    return 0;
}

int clock_evict(uintptr_t *out_backing_pa) {
    for (int i = 0; i < 2048; i++) {
        int ppn = clock_hand;
        clock_hand = (clock_hand + 1) % 1024;

        if (frames[ppn].used) {
            if (frames[ppn].ref == 0) {
                frames[ppn].used = 0;
                if (out_backing_pa) *out_backing_pa = frames[ppn].backing_pa;
                return ppn;
            } else {
                frames[ppn].ref = 0;
            }
        }
    }
    return -1;
}
