/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"

#if __SIZEOF_LONG_DOUBLE__ == __SIZEOF_DOUBLE__
#include <math.h>

long double coshl(long double x)
{
  return cosh(x);
}
#else

#ifndef _SET_ERRNO
#define _SET_ERRNO(x)
#endif

long double coshl(long double x)
{
  long double y;
  int x_class = fpclassify (x);
  if (x_class == FP_NAN)
    {
      errno = EDOM;
      return x;
    }
  else if (x_class == FP_INFINITE)
    {
       errno = ERANGE;
       return INFINITY;
    }
  x = fabsl (x);
  if (x > (MAXLOGL + LOGE2L))
    {
      errno = ERANGE;
#ifdef INFINITIES
      return (INFINITYL);
#else
      return (MAXNUML);
#endif
    }
  if (x >= (MAXLOGL - LOGE2L))
    {
      y = expl(0.5L * x);
      y = (0.5L * y) * y;
      return y;
    }
  y = expl(x);
  y = 0.5L * (y + 1.0L / y);
  return y;
}
#endif
