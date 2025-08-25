/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <math.h>

#define __FP_SIGNBIT  0x0200


int __signbitl (long double x) {
#if (defined(_AMD64_) && !defined(_ARM64EC_)) || (defined(__x86_64__) && !defined(__arm64ec__))
    __mingw_ldbl_type_t ld;
    ld.x = x;
    return ((ld.lh.sign_exponent & 0x8000) != 0);
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_) || defined(__arm64ec__) || defined(_ARM64EC_)
    return __signbit(x);
#elif defined(__i386__) || defined(_X86_)
  unsigned short sw;
  __asm__ __volatile__ ("fxam; fstsw %%ax;"
	   : "=a" (sw)
	   : "t" (x) );
  return (sw & __FP_SIGNBIT) != 0;
#endif
}

int __attribute__ ((alias ("__signbitl"))) signbitl (long double);
