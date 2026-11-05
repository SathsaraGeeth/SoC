#ifndef DMCTP_MATH_FP8_H
#define DMCTP_MATH_FP8_H

#include <stdint.h>

/*
 * S1E4M3 as implemented by mac_fp8_fp8_fp8_61:
 * exponent bias 7, exponent-zero values flush to zero, and exponent 15 is
 * unused. Finite results saturate to +/-0x77.
 */
typedef uint8_t fp8_e4m3_t;

fp8_e4m3_t fp8_e4m3_from_q16(int32_t value);
fp8_e4m3_t fp8_e4m3_from_q32(int64_t value);
int32_t fp8_e4m3_to_q16(fp8_e4m3_t value);
int64_t fp8_e4m3_to_q32(fp8_e4m3_t value);
fp8_e4m3_t fp8_e4m3_from_int(int value);

#endif
