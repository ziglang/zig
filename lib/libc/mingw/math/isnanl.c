/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

int
__isnanl (long double _x)
{
#if defined(__x86_64__) || defined(_AMD64_)
  __mingw_ldbl_type_t ld;
  int xx, signexp;

  ld.x = _x;
  signexp = (ld.lh.sign_exponent & 0x7fff) << 1;
  xx = (int) (ld.lh.low | (ld.lh.high & 0x7fffffffu)); /* explicit */
  signexp |= (unsigned int) (xx | (-xx)) >> 31;
  signexp = 0xfffe - signexp;
  return (int) ((unsigned int) signexp) >> 16;
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    return __isnan(_x);
#elif defined(__i386__) || defined(_X86_)
  unsigned short _sw;
  __asm__ __volatile__ ("fxam;"
	   "fstsw %%ax": "=a" (_sw) : "t" (_x));
  return (_sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
    == FP_NAN;
#endif
}

int __attribute__ ((alias ("__isnanl"))) isnanl (long double);
