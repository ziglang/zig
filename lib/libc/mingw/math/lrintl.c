/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

long lrintl (long double x) 
{
  long retval = 0l;
#if __SIZEOF_LONG_DOUBLE__ == __SIZEOF_DOUBLE__
    retval = lrint(x);
#elif defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");
#endif
  return retval;
}

