/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

float expm1f(float x)
{
  // Intentionally using double version of exp() here in the float version of
  // expm1, to preserve as much accuracy as possible in the intermediate
  // result.
  return exp(x) - 1.0;
}
