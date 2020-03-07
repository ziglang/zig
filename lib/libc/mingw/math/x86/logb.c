/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
 * Written by J.T. Conklin <jtc@netbsd.org>.
 * Changes for long double by Ulrich Drepper <drepper@cygnus.com>
 * Public domain.
 */

#include <math.h>

double
logb (double x)
{
#ifdef __x86_64__
  __mingw_dbl_type_t hlp;
  int lx, hx;

  hlp.x = x;
  lx = hlp.lh.low;
  hx = hlp.lh.high & 0x7fffffff; /* high |x| */
  if ((hx | lx) == 0)
    return -1.0 / fabs (x);
  if (hx >= 0x7ff00000)
    return x * x;
  if ((hx >>= 20) == 0) {
    unsigned long long mantissa = hlp.val & 0xfffffffffffffULL;
    return -1023.0 - (__builtin_clzll(mantissa) - 12);
  }
  return (double) (hx - 1023);
#else
  double res = 0.0;
  asm volatile (
       "fxtract\n\t"
       "fstp	%%st" : "=t" (res) : "0" (x));
  return res;
#endif
}
