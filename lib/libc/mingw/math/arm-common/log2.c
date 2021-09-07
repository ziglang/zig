/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <stdint.h>

typedef union ieee754_double_ {
  struct __attribute__((__packed__)) {
    uint64_t f52 : 52;
    uint64_t exp : 11;
    uint64_t sgn :  1;
  };
  double f;
} ieee754_double;

typedef union ieee754_float_ {
  struct __attribute__((__packed__)) {
    uint32_t f23 : 23;
    uint32_t exp :  8;
    uint32_t sgn :  1;
  };
  float f;
} ieee754_float;

double log2(double x)
{
    ieee754_double u = { .f = x };
    if (u.sgn == 0 && u.f52 == 0 && u.exp > 0 && u.exp < 0x7ff) {
        // Handle exact powers of two exactly
        return (int)u.exp - 1023;
    }
    return log(x) / 0.69314718246459960938;
}

float log2f(float x)
{
    ieee754_float u = { .f = x };
    if (u.sgn == 0 && u.f23 == 0 && u.exp > 0 && u.exp < 0xff) {
        // Handle exact powers of two exactly
        return (int)u.exp - 127;
    }
    return logf(x) / 0.69314718246459960938f;
}

long double log2l(long double x)
{
#if defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    return log2(x);
#else
#error Not supported on your platform yet
#endif
}
