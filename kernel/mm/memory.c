#include "memory.h"
#include <stdint.h>

void *mm_memcpy(void *destination, const void *source, size_t size)
{
    uint8_t *out = destination;
    const uint8_t *in = source;

    while (size && (((uintptr_t)out | (uintptr_t)in) &
                    (sizeof(uintptr_t) - 1))) {
        *out++ = *in++;
        --size;
    }
    while (size >= sizeof(uintptr_t)) {
        *(uintptr_t *)out = *(const uintptr_t *)in;
        out += sizeof(uintptr_t);
        in += sizeof(uintptr_t);
        size -= sizeof(uintptr_t);
    }
    while (size--) {
        *out++ = *in++;
    }
    return destination;
}
