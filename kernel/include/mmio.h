#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

static inline void reg32_write(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

static inline uint32_t reg32_read(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}

static inline void reg64_write(uintptr_t addr, uint64_t val) {
    *(volatile uint64_t *)addr = val;
}

static inline uint64_t reg64_read(uintptr_t addr) {
    return *(volatile uint64_t *)addr;
}

#endif
