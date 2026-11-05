/*
 * Minimal freestanding compiler runtime for the DMCTP RV32I_Zmmul ABI.
 *
 * Zmmul provides MUL in hardware but intentionally omits DIV and REM.  Clang
 * lowers those operations to these standard compiler-rt/libgcc entry points.
 */

typedef unsigned int u32;

static u32 udivmod32(u32 dividend, u32 divisor, u32 *remainder)
{
    u32 quotient = 0;
    u32 rem = 0;
    int bit;

    if (divisor == 0) {
        if (remainder)
            *remainder = dividend;
        return ~0u;
    }

    for (bit = 31; bit >= 0; --bit) {
        rem = (rem << 1) | ((dividend >> bit) & 1u);
        if (rem >= divisor) {
            rem -= divisor;
            quotient |= 1u << bit;
        }
    }

    if (remainder)
        *remainder = rem;
    return quotient;
}

u32 __udivsi3(u32 dividend, u32 divisor)
{
    return udivmod32(dividend, divisor, 0);
}

u32 __umodsi3(u32 dividend, u32 divisor)
{
    u32 remainder;
    (void)udivmod32(dividend, divisor, &remainder);
    return remainder;
}

int __divsi3(int dividend, int divisor)
{
    u32 dividend_abs = dividend < 0 ? 0u - (u32)dividend : (u32)dividend;
    u32 divisor_abs = divisor < 0 ? 0u - (u32)divisor : (u32)divisor;
    u32 quotient = udivmod32(dividend_abs, divisor_abs, 0);

    return ((dividend < 0) != (divisor < 0)) ? (int)(0u - quotient) : (int)quotient;
}

int __modsi3(int dividend, int divisor)
{
    u32 dividend_abs = dividend < 0 ? 0u - (u32)dividend : (u32)dividend;
    u32 divisor_abs = divisor < 0 ? 0u - (u32)divisor : (u32)divisor;
    u32 remainder;

    (void)udivmod32(dividend_abs, divisor_abs, &remainder);
    return dividend < 0 ? (int)(0u - remainder) : (int)remainder;
}

/*
 * Widen an IEEE-754 binary32 value to binary64 using integer operations.
 * DMCTP uses this standard compiler-runtime entry point for C's mandatory
 * float-to-double promotion at variadic call sites. It does not imply FP64
 * arithmetic hardware support.
 */
double __extendsfdf2(float value)
{
    union {
        float value;
        u32 bits;
    } source = { .value = value };
    union {
        double value;
        unsigned long long bits;
    } destination;
    u32 source_bits = source.bits;
    u32 exponent = (source_bits >> 23) & 0xffu;
    u32 fraction = source_bits & 0x7fffffu;
    unsigned long long sign = (unsigned long long)(source_bits >> 31) << 63;

    if (exponent == 0xffu) {
        destination.bits = sign | (0x7ffull << 52)
                         | ((unsigned long long)fraction << 29);
        if (fraction)
            destination.bits |= 1ull << 51; /* Return a quiet NaN. */
        return destination.value;
    }

    if (exponent == 0) {
        if (fraction == 0) {
            destination.bits = sign;
            return destination.value;
        }

        int leading = 22;
        while ((fraction & (1u << leading)) == 0) leading--;
        destination.bits = sign
            | (unsigned long long)(leading - 149 + 1023) << 52
            | (unsigned long long)(fraction ^ (1u << leading))
                  << (52 - leading);
        return destination.value;
    }

    destination.bits = sign
        | (unsigned long long)(exponent - 127 + 1023) << 52
        | (unsigned long long)fraction << 29;
    return destination.value;
}
