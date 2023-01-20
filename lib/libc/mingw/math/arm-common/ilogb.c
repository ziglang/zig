/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <limits.h>

int ilogb(double x)
{
  if (x == 0.0)
    return FP_ILOGB0;
  if (isinf(x))
    return INT_MAX;
  if (isnan(x))
    return FP_ILOGBNAN;
  return (int) logb(x);
}
