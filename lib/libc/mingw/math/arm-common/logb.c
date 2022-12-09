/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <limits.h>

extern double (* __MINGW_IMP_SYMBOL(_logb))(double);

double logb(double x)
{
  if (isinf(x))
    return INFINITY;
  return __MINGW_IMP_SYMBOL(_logb)(x);
}
