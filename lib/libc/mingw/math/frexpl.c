/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
long double frexpl(long double value, int* exp);

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)

double frexp(double value, int* exp);

/* On ARM `long double` is 64 bits. */
long double frexpl(long double value, int* exp)
{
  return frexp(value, exp);
}

#elif defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)

#include <stdint.h>

/* https://en.wikipedia.org/wiki/Extended_precision#x86_extended_precision_format */
typedef union x87reg_ {
  struct __attribute__((__packed__)) {
    uint64_t f64;
    uint16_t exp : 15;
    uint16_t sgn :  1;
  };
  long double f;
} x87reg;

long double frexpl(long double value, int* exp)
{
  int n;
  x87reg reg;
  reg.f = value;
  if(reg.exp == 0x7FFF) {
    /* The value is an infinity or NaN.
     * Store zero in `*exp`. Return the value as is. */
    *exp = 0;
    return reg.f;
  }
  if(reg.exp != 0) {
    /* The value is normalized.
     * Extract and zero out the exponent. */
    *exp = reg.exp - 0x3FFE;
    reg.exp = 0x3FFE;
    return reg.f;
  }
  if(reg.f64 == 0) {
    /* The value is zero.
     * Store zero in `*exp`. Return the value as is.
     * Note the signness. */
    *exp = 0;
    return reg.f;
  }
  /* The value is denormalized.
   * Extract the exponent, normalize the value, then zero out
   * the exponent. Note that x87 uses an explicit leading bit. */
  n = __builtin_clzll(reg.f64);
  reg.f64 <<= n;
  *exp = 1 - 0x3FFE - n;
  reg.exp = 0x3FFE;
  return reg.f;
}

#else

#error Please add `frexpl()` implementation for this platform.

#endif
