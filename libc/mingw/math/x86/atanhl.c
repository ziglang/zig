/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>
#include "fastmath.h"

/* atanh (x) = 0.5 * log ((1.0 + x)/(1.0 - x)) */
long double atanhl (long double x)
{
  long double z;
  if (isnan (x))
    return x;
  z = fabsl (x);
  if (z == 1.0L)
    {
      errno  = ERANGE;
      return (x > 0 ? INFINITY : -INFINITY);
    }
  if ( z > 1.0L)
    {
      errno = EDOM;
      return nanl("");
    }
  /* Rearrange formula to avoid precision loss for small x.
  atanh(x) = 0.5 * log ((1.0 + x)/(1.0 - x))
 	   = 0.5 * log1p ((1.0 + x)/(1.0 - x) - 1.0)
           = 0.5 * log1p ((1.0 + x - 1.0 + x) /(1.0 - x)) 
           = 0.5 * log1p ((2.0 * x ) / (1.0 - x))  */
  z = 0.5L * __fast_log1pl ((z + z) / (1.0L - z));
  return x >= 0 ? z : -z;
}
