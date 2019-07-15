/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <limits.h>
#include <errno.h>

long
lroundf (float x)
{
  float res;

  if (x >= 0.0F)
    {
      res = ceilf (x);
      if (res - x > 0.5F)
	res -= 1.0F;
    }
  else
    {
      res = ceilf (-x);
      if (res + x > 0.5F)
	res -= 1.0F;
      res = -res;
    }
  if (!isfinite (res)
      || res > (float) LONG_MAX
      || res < (float) LONG_MIN)
    {
      errno = ERANGE;
      /* Undefined behaviour, so we could return anything.  */
      /* return res > 0.0F ? LONG_MAX : LONG_MIN; */
    }
  return (long) res;
}
