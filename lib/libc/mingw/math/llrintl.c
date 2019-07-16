/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <fenv.h>

long long llrintl (long double x) 
{
  long long retval = 0ll;
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  __asm__ __volatile__ ("fistpll %0"  : "=m" (retval) : "t" (x) : "st");
#else
  int mode = fegetround();
  if (mode == FE_DOWNWARD)
    retval = (long long)floor(x);
  else if (mode == FE_UPWARD)
    retval = (long long)ceil(x);
  else if (mode == FE_TOWARDZERO)
    retval = x >= 0 ? (long long)floor(x) : (long long)ceil(x);
  else
    retval = x >= 0 ? (long long)floor(x + 0.5) : (long long)ceil(x - 0.5);
#endif
  return retval;
}

