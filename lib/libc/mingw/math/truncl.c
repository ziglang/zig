/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>
#include <math.h>

long double
truncl (long double _x)
{
#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)
  return trunc(_x);
#else
  long double retval = 0.0L;
  unsigned short saved_cw;
  unsigned short tmp_cw;
  __asm__ __volatile__ ("fnstcw %0;" : "=m" (saved_cw)); /* save FPU control word */
  tmp_cw = (saved_cw & ~(FE_TONEAREST | FE_DOWNWARD | FE_UPWARD | FE_TOWARDZERO))
	    | FE_TOWARDZERO;
  __asm__ __volatile__ ("fldcw %0;" : : "m" (tmp_cw));
  __asm__ __volatile__ ("frndint;" : "=t" (retval)  : "0" (_x)); /* round towards zero */
  __asm__ __volatile__ ("fldcw %0;" : : "m" (saved_cw) ); /* restore saved control word */
  return retval;
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
}
