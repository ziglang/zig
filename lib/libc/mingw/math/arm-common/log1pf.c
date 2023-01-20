/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

float log1pf(float x)
{
  // Intentionally using double version of log() here in the float version of
  // log1p, to preserve as much accuracy as possible in the intermediate
  // parameter.
  return log(x + 1.0);
}
