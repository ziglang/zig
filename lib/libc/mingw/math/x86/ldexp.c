/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>

double ldexp(double x, int expn)
{
  double res = 0.0;
  if (!isfinite (x) || x == 0.0)
    return x;

  __asm__ __volatile__ ("fscale"
  	    : "=t" (res)
	    : "0" (x), "u" ((double) expn));

  if (!isfinite (res) || res == 0.0L)
    errno = ERANGE;

  return res;
}
