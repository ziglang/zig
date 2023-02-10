/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <limits.h>

extern float (* __MINGW_IMP_SYMBOL(powf))(float, float);

float powf(float x, float y)
{
  if (x == 1.0f)
    return 1.0f;
  if (y == 0.0f)
    return 1.0f;
  if (x == -1.0f && isinf(y))
    return 1.0f;
  return __MINGW_IMP_SYMBOL(powf)(x, y);
}
