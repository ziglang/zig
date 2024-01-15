/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

#if defined(_AMD64_) || defined(__x86_64__)
#include <xmmintrin.h>
#endif

long lrint (double x) 
{
  long retval = 0L;
#if defined(_AMD64_) || defined(__x86_64__)
  retval = _mm_cvtsd_si32(_mm_load_sd(&x));
#elif defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");
#elif defined(__arm__) || defined(_ARM_)
  float temp;
  __asm__ __volatile__ (
    "vcvtr.s32.f64    %[tmp], %[src]\n\t"
    "fmrs             %[dst], %[tmp]\n\t"
    : [dst] "=r" (retval), [tmp] "=t" (temp) : [src] "w" (x));
#elif defined(__aarch64__) || defined(_ARM64_)
  __asm__ __volatile__ (
    "frintx %d1, %d1\n\t"
    "fcvtzs %w0, %d1\n\t"
    : "=r" (retval), "+w" (x));
#endif
  return retval;
}
