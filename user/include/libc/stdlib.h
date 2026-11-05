#ifndef DMCTP_STDLIB_H
#define DMCTP_STDLIB_H

#include <sys/types.h>

void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
int abs(int value);
long strtol(const char *restrict str, char **restrict end, int base);
float strtof(const char *restrict str, char **restrict end);
void qsort(void *base, size_t count, size_t size,
           int (*compare)(const void *, const void *));

#endif
