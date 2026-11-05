#include <stdint.h>

uint64_t materialize_constants(uint64_t value)
{
    value += UINT64_C(0x315);
    value ^= UINT64_C(0x127);
    return value & UINT64_C(0x3ff);
}
