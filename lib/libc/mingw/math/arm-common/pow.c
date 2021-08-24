/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <limits.h>

extern double (* __MINGW_IMP_SYMBOL(pow))(double, double);

double pow(double x, double y)
{
  if (x == 1.0)
    return 1.0;
  if (y == 0.0)
    return 1.0;
  if (x == -1.0 && isinf(y))
    return 1.0;
  return __MINGW_IMP_SYMBOL(pow)(x, y);
}
