/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

float rintf (float x) {
  float retval = 0.0F;
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("frndint;": "=t" (retval) : "0" (x));
#elif defined(__arm__) || defined(_ARM_)
  if (isnan(x) || isinf(x))
    return x;
  __asm__ __volatile__ (
    "vcvtr.s32.f32    %[dst], %[src]\n\t"
    "vcvt.f32.s32     %[dst], %[dst]\n\t"
    : [dst] "=t" (retval) : [src] "w" (x));
#elif defined(__aarch64__) || defined(_ARM64_)
  __asm__ __volatile__ ("frintx %s0, %s1\n\t" : "=w" (retval) : "w" (x));
#endif
  return retval;
}
