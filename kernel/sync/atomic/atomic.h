/*
 * kernel/sync/atomic/atomic.h
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. define atomic integer types
 * 2. define atomic operations
 *     i.   atomic read
 *     ii.  atomic write
 *     iii. atomic add
 *     iv.  atomic compare and exchange
 * 3. implemented using lr/sc semantics
 */

#ifndef ATOMIC_H
#define ATOMIC_H

#include <stdint.h>

typedef struct {
    volatile int64_t  value;
} aint64_t;

typedef struct {
    volatile int32_t  value;
} aint32_t;

int64_t  atomic_read_aint64(const aint64_t *ptr);
int32_t  atomic_read_aint32(const aint32_t *ptr);

void     atomic_write_aint64(aint64_t *ptr, int64_t value);
void     atomic_write_aint32(aint32_t *ptr, int32_t value);

int64_t  atomic_add_aint64(aint64_t *ptr, int64_t value);
int32_t  atomic_add_aint32(aint32_t *ptr, int32_t value);

int64_t  atomic_cmpxchg_aint64(aint64_t *ptr, int64_t expected, int64_t desired);
int32_t  atomic_cmpxchg_aint32(aint32_t *ptr, int32_t expected, int32_t desired);

#endif /* ATOMIC_H */
