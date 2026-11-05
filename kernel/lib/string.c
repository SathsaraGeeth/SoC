#include <stddef.h>

void *memcpy(void *restrict dst, const void *restrict src, size_t count) {
    unsigned char *out = dst;
    const unsigned char *in = src;

    while (count--)
        *out++ = *in++;
    return dst;
}
