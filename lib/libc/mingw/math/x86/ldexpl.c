/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>

long double ldexpl(long double x, int expn)
{
  long double res = 0.0L;
  if (!isfinite (x) || x == 0.0L)
    return x;

  __asm__ __volatile__ ("fscale"
  	    : "=t" (res)
	    : "0" (x), "u" ((long double) expn));

  if (!isfinite (res) || res == 0.0L)
    errno = ERANGE;

  return res;
}
