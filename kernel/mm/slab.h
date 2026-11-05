#ifndef SLAB_H
#define SLAB_H

#include <stdint.h>
#include <stddef.h>

void  slab_init(uint32_t start, uint32_t size);
void *kmalloc(size_t size);
void  kfree(void *ptr);

#endif
