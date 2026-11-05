#include <math/fp8.h>

#define FP8_SIGN_MASK 0x80u
#define FP8_EXP_MASK  0x0fu
#define FP8_MAN_MASK  0x07u
#define FP8_MIN       0x08u
#define FP8_MAX       0x77u

static uint64_t fp8_magnitude_scaled(fp8_e4m3_t value,
                                     unsigned fractional_bits) {
    unsigned exponent = (value >> 3) & FP8_EXP_MASK;
    unsigned mantissa = value & FP8_MAN_MASK;
    int shift;

    if (exponent == 0 || exponent == FP8_EXP_MASK) return 0;
    shift = (int)fractional_bits + (int)exponent - 10;
    if (shift >= 0) return (uint64_t)(8u + mantissa) << shift;
    return (uint64_t)(8u + mantissa) >> -shift;
}

static fp8_e4m3_t fp8_from_scaled(int64_t value, unsigned fractional_bits) {
    uint64_t magnitude;
    uint64_t minimum;
    uint64_t best_error = UINT64_MAX;
    fp8_e4m3_t best = FP8_MIN;
    unsigned sign = 0;

    if (value == 0) return 0;
    if (value < 0) {
        sign = FP8_SIGN_MASK;
        magnitude = (uint64_t)(-(value + 1)) + 1;
    } else {
        magnitude = (uint64_t)value;
    }

    minimum = fp8_magnitude_scaled(FP8_MIN, fractional_bits);
    if (magnitude < minimum) return 0;

    for (unsigned candidate = FP8_MIN; candidate <= FP8_MAX; candidate++) {
        uint64_t decoded = fp8_magnitude_scaled((fp8_e4m3_t)candidate,
                                                fractional_bits);
        uint64_t error = decoded > magnitude
                       ? decoded - magnitude
                       : magnitude - decoded;

        if (error < best_error ||
            (error == best_error && !(candidate & 1u) && (best & 1u))) {
            best_error = error;
            best = (fp8_e4m3_t)candidate;
        }
    }
    return (fp8_e4m3_t)(sign | best);
}

static int64_t fp8_to_scaled(fp8_e4m3_t value, unsigned fractional_bits) {
    uint64_t magnitude = fp8_magnitude_scaled(value, fractional_bits);
    return value & FP8_SIGN_MASK ? -(int64_t)magnitude : (int64_t)magnitude;
}

fp8_e4m3_t fp8_e4m3_from_q16(int32_t value) {
    return fp8_from_scaled(value, 16);
}

fp8_e4m3_t fp8_e4m3_from_q32(int64_t value) {
    return fp8_from_scaled(value, 32);
}

int32_t fp8_e4m3_to_q16(fp8_e4m3_t value) {
    return (int32_t)fp8_to_scaled(value, 16);
}

int64_t fp8_e4m3_to_q32(fp8_e4m3_t value) {
    return fp8_to_scaled(value, 32);
}

fp8_e4m3_t fp8_e4m3_from_int(int value) {
    return fp8_e4m3_from_q16((int32_t)value * 65536);
}
