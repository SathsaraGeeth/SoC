#include <stdint.h>

uint64_t integer_mix(uint64_t a, uint64_t b)
{
    uint64_t product = a * b;
    uint64_t bits = (a + UINT64_C(0x315)) ^ (b - UINT64_C(0x127));
    return (product + bits) ^ (a & b) ^ (a | b);
}

int64_t signed_mix(int64_t a, int64_t b)
{
    int64_t wide = a * b;
    return wide + a - b;
}
