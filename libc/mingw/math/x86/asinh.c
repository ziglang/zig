/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>
#include "fastmath.h"

 /* asinh(x) = copysign(log(fabs(x) + sqrt(x * x + 1.0)), x) */
double asinh(double x)
{
  double z;
  if (!isfinite (x))
    return x;
  z = fabs (x);

  /* Avoid setting FPU underflow exception flag in x * x. */
#if 0
  if ( z < 0x1p-32)
    return x;
#endif

  /* Use log1p to avoid cancellation with small x. Put
     x * x in denom, so overflow is harmless. 
     asinh(x) = log1p (x + sqrt (x * x + 1.0) - 1.0)
              = log1p (x + x * x / (sqrt (x * x + 1.0) + 1.0))  */

  z = __fast_log1p (z + z * z / (__fast_sqrt (z * z + 1.0) + 1.0));

  return ( x > 0.0 ? z : -z);
}

