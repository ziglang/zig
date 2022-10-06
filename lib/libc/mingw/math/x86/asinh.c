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

  /* NB the previous formula
          z = __fast_log1p (z + z * z / (__fast_sqrt (z * z + 1.0) + 1.0));
     was defective in two ways:
     1: It ommitted required brackets:
          z = __fast_log1p (z + z * (z / (__fast_sqrt (z * z + 1.0) + 1.0)));
                                    ^                                     ^
        so would still overflow for large z.
     2: Even with the brackets, it still degraded quickly for large z
        (where z*z+1 == z*z).
        e.g. asinh (sinh 356.0)) gave 355.30685281944005
    */

  const double asinhCutover = pow(2,DBL_MAX_EXP/2); // 1.3407807929943e+154

  if (z < asinhCutover)
  /* After excluding large values, the rearranged formula gives better results
     the original formula log(z + sqrt(z * z + 1.0)) for very small z.
        e.g. rearranged asinh(sinh 2e-301)) = 2e-301
             original   asinh(sinh 2e-301)) = 0.
     asinh(z) = log   (z + sqrt (z * z + 1.0))
              = log1p (z + sqrt (z * z + 1.0) - 1.0)
              = log1p (z + (sqrt (z * z + 1.0) - 1.0)
                         * (sqrt (z * z + 1.0) + 1.0)
                         / (sqrt (z * z + 1.0) + 1.0))
              = log1p (z + ((z * z + 1.0) - 1.0)
                         / (sqrt (z * z + 1.0) + 1.0))
              = log1p (z + z * z / (sqrt (z * z + 1.0) + 1.0))
    */
    z = __fast_log1p (z + z * (z / (__fast_sqrt (z * z + 1.0) + 1.0)));
  else
  /* above this, z*z+1 == z*z, so we can simplify
     (and avoid z*z being infinity).
      asinh(z) = log (z + sqrt (z * z + 1.0))
               = log (z + sqrt (z * z      ))
               = log (2 * z)
               = log 2 + log z
      Choosing asinhCutover is a little tricky.
      We'd like something that's based on the nature of
      the numeric type (DBL_MAX_EXP, etc).
      If c = asinhCutover, then we need:
         (1) c*c == c*c + 1
         (2) log (2*c) = log 2 + log c.
      For float:
         9.490626562425156e7 is the smallest value that
         achieves (1), but it fails (2). (It only just fails,
         but enough to make the function erroneously non-monotonic).
    */
    z = __fast_log(2) + __fast_log(z);
  return copysign(z, x); //ensure 0.0 -> 0.0 and -0.0 -> -0.0.
}
