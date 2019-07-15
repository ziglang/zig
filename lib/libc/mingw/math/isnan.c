/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

int
__isnan (double _x)
{
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_dbl_type_t hlp;
    int l, h;

    hlp.x = _x;
    l = hlp.lh.low;
    h = hlp.lh.high & 0x7fffffff;
    h |= (unsigned int) (l | -l) >> 31;
    h = 0x7ff00000 - h;
    return (int) ((unsigned int) h) >> 31;
#elif defined(__i386__) || defined(_X86_)
  unsigned short _sw;
  __asm__ __volatile__ ("fxam;"
	   "fstsw %%ax": "=a" (_sw) : "t" (_x));
  return (_sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
    == FP_NAN;
#endif
}

#undef isnan
int __attribute__ ((alias ("__isnan"))) isnan (double);
