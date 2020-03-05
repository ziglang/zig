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

float
logbf (float x)
{
#ifdef __x86_64__
    int v;
    __mingw_flt_type_t hlp;

    hlp.x = x;
    v = hlp.val & 0x7fffffff;  /* high |x| */
    if (!v)
      return (float)-1.0 / fabsf (x);
    if (v >= 0x7f800000)
      return x * x;
    if ((v >>= 23) == 0)
      return -127.0 - (__builtin_clzl(hlp.val & 0x7fffff) - 9);
    return (float) (v - 127);
#else
  float res = 0.0F;
  asm volatile (
       "fxtract\n\t"
       "fstp	%%st" : "=t" (res) : "0" (x));
  return res;
#endif
}
