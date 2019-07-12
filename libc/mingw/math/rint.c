/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

double rint (double x) {
  double retval = 0.0;
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("frndint;" : "=t" (retval) : "0" (x));
#elif defined(__arm__) || defined(_ARM_)
  if (isnan(x) || isinf(x))
    return x;
  float temp;
  __asm__ __volatile__ (
    "vcvtr.s32.f64    %[tmp], %[src]\n\t"
    "vcvt.f64.s32     %[dst], %[tmp]\n\t"
    : [dst] "=w" (retval), [tmp] "=t" (temp) : [src] "w" (x));
#elif defined(__aarch64__) || defined(_ARM64_)
  __asm__ __volatile__ ("frintx %d0, %d1\n\t" : "=w" (retval) : "w" (x));
#endif
  return retval;
}
