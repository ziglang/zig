/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>
#include <float.h>
#include "fastmath.h"

 /* asinh(x) = copysign(log(fabs(x) + sqrt(x * x + 1.0)), x) */
long double asinhl(long double x)
{
  long double z;
  if (!isfinite (x))
    return x;

  z = fabsl (x);

  /* Avoid setting FPU underflow exception flag in x * x. */
#if 0
  if ( z < 0x1p-32)
    return x;
#endif

  /* See commentary in asinh */
  const long double asinhCutover = powl(2,LDBL_MAX_EXP/2);

  if (z < asinhCutover)
    z = __fast_log1pl (z + z * (z / (__fast_sqrtl (z * z + 1.0) + 1.0)));
  else
    z = __fast_logl(2) + __fast_logl(z);
  return copysignl(z, x); //ensure 0.0 -> 0.0 and -0.0 -> -0.0.
}
