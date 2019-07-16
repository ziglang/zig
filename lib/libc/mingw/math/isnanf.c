/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
int
__isnanf (float _x)
{
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_flt_type_t hlp;
    int i;
    
    hlp.x = _x;
    i = hlp.val & 0x7fffffff;
    i = 0x7f800000 - i;
    return (int) (((unsigned int) i) >> 31);
#elif defined(__i386__) || defined(_X86_)
  unsigned short _sw;
  __asm__ __volatile__ ("fxam;"
	   "fstsw %%ax": "=a" (_sw) : "t" (_x) );
  return (_sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
    == FP_NAN;
#endif
}

int __attribute__ ((alias ("__isnanf"))) isnanf (float);
