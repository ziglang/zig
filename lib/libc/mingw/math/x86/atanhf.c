/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>
#include "fastmath.h"

/* atanh (x) = 0.5 * log ((1.0 + x)/(1.0 - x)) */
float atanhf (float x)
{
  float z;
  if (isnan (x))
    return x;
  z = fabsf (x);
  if (z == 1.0)
    {
      errno  = ERANGE;
      return (x > 0 ? INFINITY : -INFINITY);
    }
  if ( z > 1.0)
    {
      errno = EDOM;
      return nanf("");
    }
  /* Rearrange formula to avoid precision loss for small x.

  atanh(x) = 0.5 * log ((1.0 + x)/(1.0 - x))
	   = 0.5 * log1p ((1.0 + x)/(1.0 - x) - 1.0)
           = 0.5 * log1p ((1.0 + x - 1.0 + x) /(1.0 - x)) 
           = 0.5 * log1p ((2.0 * x ) / (1.0 - x))  */
  z = 0.5 * __fast_log1p ((z + z) / (1.0 - z));
  return copysignf(z, x); //ensure 0.0 -> 0.0 and -0.0 -> -0.0.
}
