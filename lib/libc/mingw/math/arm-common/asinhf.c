/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

float asinhf(float x)
{
  if (isinf(x*x + 1)) {
    if (x > 0)
      return logf(2) + logf(x);
    else
      return -logf(2) - logf(-x);
  }
  return logf(x + sqrtf(x*x + 1));
}
