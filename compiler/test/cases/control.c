#include <stdint.h>

uint64_t branch_loop(uint64_t value, uint64_t rounds)
{
    for (uint64_t i = 0; i < rounds; ++i) {
        value = (value & 1u) ? value + 3u : value - 2u;
    }
    return value;
}
