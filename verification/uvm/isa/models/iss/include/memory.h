/*
 * Comments:
 * 1. Abstracts the memory
 */

#ifndef DMCTP_ISS_MEMORY_H
#define DMCTP_ISS_MEMORY_H

#include <stdint.h>

typedef struct mem {
    uint64_t value;
    uint32_t owner;
    uint8_t  locked;
} mem_t;

typedef struct isa isa_t;

typedef struct mem_methods {
    uint64_t (*read)   (isa_t *isa, uint64_t address, unsigned bytes);
    void     (*write)  (isa_t *isa, uint64_t address, uint64_t value, unsigned bytes);
    void     (*reserve)(isa_t *isa, uint64_t address);
    void     (*release)(isa_t *isa);
} mem_methods_t;

#endif /* DMCTP_ISS_MEMORY_H */
