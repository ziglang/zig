/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

float acoshf(float x)
{
  if (x < 1.0)
    return NAN;
  if (isinf(x*x))
    return logf(2) + logf(x);
  return logf(x + sqrtf(x*x - 1));
}
