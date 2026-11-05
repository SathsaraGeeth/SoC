/*
 * Comments:
 * 1. Bump allocator
 * 2. No free, at least for now
 */

#ifndef HEAP_H
#define HEAP_H

#include <stdint.h>
#include <stddef.h>

void  heap_init(uint32_t start, uint32_t size);
void  *kmalloc(size_t size);
// void  kfree(void *ptr);

#endif
