/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <limits.h>
#include <errno.h>

long
lroundl (long double x)
{
  long double res;

  if (x >= 0.0L)
    {
      res = ceill (x);
      if (res - x > 0.5L)
	res -= 1.0;
    }
  else
    {
      res = ceill (-x);
      if (res + x > 0.5L)
	res -= 1.0L;
      res = -res;
    }
  if (!isfinite (res)
      || res > (long double)LONG_MAX
      || res < (long double)LONG_MIN)
    {
      errno = ERANGE;
      /* Undefined behaviour, so we could return anything.  */
      /* return res > 0.0L ? LONG_MAX : LONG_MIN;  */
    }
  return (long) res;
}
