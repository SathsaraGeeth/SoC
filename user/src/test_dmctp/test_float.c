/*
 * Comments:
 * 1. Exercises FP32 values in the unified register file.
 */

#include <stdint.h>
#include <stdio.h>

#ifdef DMCTP_EXPERIMENTAL

static uint32_t float_bits(float value) {
    union {
        float value;
        uint32_t bits;
    } representation;
    representation.value = value;
    return representation.bits;
}

static int expect_bits(const char *name, float value, uint32_t expected) {
    uint32_t actual = float_bits(value);
    if (actual != expected) {
        printf("FAIL %s actual=0x%x expected=0x%x\n", name, actual, expected);
        return 1;
    }
    printf("PASS %s bits=0x%x\n", name, actual);
    return 0;
}

static unsigned long fp_eq(float lhs, float rhs) {
    unsigned long result;
    __asm__ volatile("FEQ.f32 %0, %1, %2"
                     : "=r"(result) : "r"(lhs), "r"(rhs));
    return result;
}

static unsigned long fp_lt(float lhs, float rhs) {
    unsigned long result;
    __asm__ volatile("FLT.f32 %0, %1, %2"
                     : "=r"(result) : "r"(lhs), "r"(rhs));
    return result;
}

static unsigned long fp_le(float lhs, float rhs) {
    unsigned long result;
    __asm__ volatile("FLE.f32 %0, %1, %2"
                     : "=r"(result) : "r"(lhs), "r"(rhs));
    return result;
}

int main(void) {
    volatile float a = 1.5f;
    volatile float b = 2.25f;
    volatile int seven = 7;
    int failures = 0;
    union {
        double value;
        unsigned long long bits;
    } promoted;

    failures += expect_bits("add", a + b, 0x40700000u);
    failures += expect_bits("sub", b - a, 0x3f400000u);
    failures += expect_bits("mul", a * b, 0x40580000u);
    failures += expect_bits("i2f", (float)seven, 0x40e00000u);

    promoted.value = a + b;
    if (promoted.bits != 0x400e000000000000ull) {
        printf("FAIL promotion bits=0x%llx\n", promoted.bits);
        failures++;
    } else {
        puts("PASS standard float-to-double promotion");
    }
    printf("FP printf: %.2f %.3f %.1f\n", a + b, a - b, (float)seven);

    if (!(a < b) || !(a <= b) || a == b) {
        puts("FAIL compare");
        failures++;
    } else {
        puts("PASS compare");
    }

    if (!fp_lt(-b, -a) || !fp_le(a, a) || !fp_eq(b, b) || fp_eq(a, b)) {
        puts("FAIL FPU compare instructions");
        failures++;
    } else {
        puts("PASS FPU compare instructions");
    }

    if ((int)(a + b) != 3) {
        puts("FAIL f2i");
        failures++;
    } else {
        puts("PASS f2i");
    }

    if (failures) {
        printf("floating-point failures=%d\n", failures);
        return 1;
    }
    puts("floating-point tests passed");
    return 0;
}

#else

int main(void) {
    puts("test_float requires the experimental native DMCTP compiler");
    return 0;
}

#endif
