/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
double frexp(double value, int* exp);

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) || \
    defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)

#include <stdint.h>

/* It is assumed that `double` conforms to IEEE 754 and is little-endian.
 * This is true on x86 and ARM. */

typedef union ieee754_double_ {
  struct __attribute__((__packed__)) {
    uint64_t f52 : 52;
    uint64_t exp : 11;
    uint64_t sgn :  1;
  };
  double f;
} ieee754_double;

double frexp(double value, int* exp)
{
  int n;
  ieee754_double reg;
  reg.f = value;
  if(reg.exp == 0x7FF) {
    /* The value is an infinity or NaN.
     * Store zero in `*exp`. Return the value as is. */
    *exp = 0;
    return reg.f;
  }
  if(reg.exp != 0) {
    /* The value is normalized.
     * Extract and zero out the exponent. */
    *exp = reg.exp - 0x3FE;
    reg.exp = 0x3FE;
    return reg.f;
  }
  if(reg.f52 == 0) {
    /* The value is zero.
     * Store zero in `*exp`. Return the value as is.
     * Note the signness. */
    *exp = 0;
    return reg.f;
  }
  /* The value is denormalized.
   * Extract the exponent, normalize the value, then zero out
   * the exponent. Note that the hidden bit is removed. */
  n = __builtin_clzll(reg.f52) - 11;
  reg.f52 <<= n;
  *exp = 1 - 0x3FE - n;
  reg.exp = 0x3FE;
  return reg.f;
}

#else

#error Please add `frexp()` implementation for this platform.

#endif
