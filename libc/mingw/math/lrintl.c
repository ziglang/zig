/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

long lrintl (long double x) 
{
  long retval = 0l;
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    retval = lrint(x);
#endif
  return retval;
}

