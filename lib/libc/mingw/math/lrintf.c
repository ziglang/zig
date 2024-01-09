/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

#if defined(_AMD64_) || defined(__x86_64__)
#include <xmmintrin.h>
#endif

long lrintf (float x) 
{
  long retval = 0l;
#if defined(_AMD64_) || defined(__x86_64__)
  retval = _mm_cvtss_si32(_mm_load_ss(&x));
#elif defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");
#elif defined(__arm__) || defined(_ARM_)
  __asm__ __volatile__ (
    "vcvtr.s32.f32    %[src], %[src]\n\t"
    "fmrs             %[dst], %[src]\n\t"
    : [dst] "=r" (retval), [src] "+w" (x));
#elif defined(__aarch64__) || defined(_ARM64_)
  __asm__ __volatile__ (
    "frintx %s1, %s1\n\t"
    "fcvtzs %w0, %s1\n\t"
    : "=r" (retval), "+w" (x));
#endif
  return retval;
}
