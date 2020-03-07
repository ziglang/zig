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
  else {
    // Break `x` into integral and fractional parts.
    long double intg, frac;
    frac = modfl(x, &intg);
    frac = fabsl(frac);
    // Convert the truncated integral part to an integer.
    retval = intg;
    if (frac < 0.5) {
      // Round towards zero.
    } else if (frac > 0.5) {
      // Round towards infinities.
      retval += signbit(x) ? -1 : 1;
    } else {
      // Round to the nearest even number.
      retval += retval % 2;
    }
  }
#endif
  return retval;
}

