/*
 This Software is provided under the Zope Public License (ZPL) Version 2.1.

 Copyright (c) 2009, 2010 by the mingw-w64 project

 See the AUTHORS file for the list of contributors to the mingw-w64 project.

 This license has been certified as open source. It has also been designated
 as GPL compatible by the Free Software Foundation (FSF).

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   1. Redistributions in source code must retain the accompanying copyright
      notice, this list of conditions, and the following disclaimer.
   2. Redistributions in binary form must reproduce the accompanying
      copyright notice, this list of conditions, and the following disclaimer
      in the documentation and/or other materials provided with the
      distribution.
   3. Names of the copyright holders must not be used to endorse or promote
      products derived from this software without prior written permission
      from the copyright holders.
   4. The right to distribute this software or to use it for any purpose does
      not give you the right to use Servicemarks (sm) or Trademarks (tm) of
      the copyright holders.  Use of them is covered by separate agreement
      with the copyright holders.
   5. If any files are modified, you must cause the modified files to carry
      prominent notices stating that you changed the files and the date of
      any change.

 Disclaimer

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY EXPRESSED
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/* IEEE 754 - Elementary Functions - Special Cases
 * pow(+/-0, oo) is +0
 * pow(+/-0, -oo) is +oo
 * pow (x, +/-0) is 1 for any x (even a zero, quiet NaN, or infinity)
 * pow (+1, y) is 1 for any y (even a quiet NaN)
 * pow (+/-0, y) is +/-oo and signals the divideByZero exception for y an odd integer < 0
 * pow (+/-0, y) is +oo and signals the divideByZero exception for finite y < 0 and not an odd integer
 * pow (+/-0, y) is +/-0 for finite y > 0 an odd integer
 * pow (+/-0, y) is +0 for finite y > 0 and not an odd integer
 * pow (-1, +/-oo) is 1 with no exception
 pow( -inf, y) = +0 for y<0 and not an odd integer
 pow( -inf, y) = -inf for y an odd integer > 0
 pow( -inf, y) = +inf for y>0 and not an odd integer
 pow (+/-inf, y) is +/-0 with no exception for y an odd integer < 0
 pow (+/-inf, -inf) is +0 with no exception
 pow (+/-inf, +inf) is +inf with no exception
 pow (+/-inf, y) is +0 with no exception for finite y < 0 and not an odd integer
 pow (+/-inf, y) is +/-inf with no exception for finite y > 0 an odd integer
 pow (+/-inf, y) is +inf with no exception for finite y > 0 and not an odd integer
 pow (x, y) signals the invalid operation exception for finite x < 0 and finite non-integer y.
 
 For x /= 0: lim y->oo (1/x)^y results as: for |x| < 1 that sgn(x)*0 and for |x| > 0 that sgn(x)*Infinity

*/
#include "../complex/complex_internal.h"
#include <errno.h>
#include <limits.h>
#include <fenv.h>
#include <math.h>
#include <errno.h>
#define FE_ROUNDING_MASK \
  (FE_TONEAREST | FE_DOWNWARD | FE_UPWARD | FE_TOWARDZERO)

static __FLT_TYPE
internal_modf (__FLT_TYPE value, __FLT_TYPE *iptr)
{
  __FLT_TYPE int_part = (__FLT_TYPE) 0.0;
  /* truncate */ 
  /* truncate */
#ifdef __x86_64__
  asm volatile ("pushq %%rax\n\tsubq $8, %%rsp\n"
    "fnstcw 4(%%rsp)\n"
    "movzwl 4(%%rsp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%rsp)\n"
    "fldcw (%%rsp)\n"
    "frndint\n"
    "fldcw 4(%%rsp)\n"
    "addq $8, %%rsp\npopq %%rax" : "=t" (int_part) : "0" (value)); /* round */
#else
  asm volatile ("push %%eax\n\tsubl $8, %%esp\n"
    "fnstcw 4(%%esp)\n"
    "movzwl 4(%%esp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%esp)\n"
    "fldcw (%%esp)\n"
    "frndint\n"
    "fldcw 4(%%esp)\n"
    "addl $8, %%esp\n\tpop %%eax\n" : "=t" (int_part) : "0" (value)); /* round */
#endif
  if (iptr)
    *iptr = int_part;
  return (isinf (value) ?  (__FLT_TYPE) 0.0 : value - int_part);
}

__FLT_TYPE __cdecl __FLT_ABI(__powi) (__FLT_TYPE x, int n);

__FLT_TYPE __cdecl
__FLT_ABI(pow) (__FLT_TYPE x, __FLT_TYPE y)
{
  int x_class = fpclassify (x);
  int y_class = fpclassify (y);
  long odd_y = 0;
  __FLT_TYPE d, rslt;

  if (y_class == FP_ZERO || x == __FLT_CST(1.0))
    return __FLT_CST(1.0);
  else if (x_class == FP_NAN || y_class == FP_NAN)
    {
      if (x_class == FP_NAN) {
        __FLT_RPT_DOMAIN ("pow", x, y, x);
        return x;
      } else {
        __FLT_RPT_DOMAIN ("pow", x, y, y);
        return y;
      }
    }
  else if (x_class == FP_ZERO)
    {
      if (y_class == FP_INFINITE)
	return (signbit(y) ? __FLT_HUGE_VAL : __FLT_CST(0.0));

      if (signbit(x) && internal_modf (y, &d) != 0.0)
	{
	  return signbit (y) ? (1.0 / -x) : __FLT_CST (0.0);
	  /*__FLT_RPT_DOMAIN ("pow", x, y, -__FLT_NAN);
	  return -__FLT_NAN; */
	}
      odd_y = (internal_modf (__FLT_ABI (ldexp) (y, -1), &d) != 0.0) ? 1 : 0;
      if (!signbit(y))
	{
	  if (!odd_y || !signbit (x))
	    return __FLT_CST (0.0);
	  return -__FLT_CST(0.0);
	}

      if (!odd_y || !signbit (x))
	return __FLT_HUGE_VAL;
      return (signbit(x) ? -__FLT_HUGE_VAL : __FLT_HUGE_VAL);
    }
  else if (y_class == FP_INFINITE)
    {
      __FLT_TYPE a_x;

      if (x_class == FP_INFINITE)
	return (signbit (y) ? __FLT_CST (0.0) : __FLT_HUGE_VAL);
      a_x = (signbit (x) ? -x : x);
      if (a_x == 1.0)
	return __FLT_CST (1.0);
      if (a_x > 1.0)
	return (signbit (y) == 0 ? __FLT_HUGE_VAL : __FLT_CST (0.0));
      return (!signbit (y) ? __FLT_CST (0.0) : __FLT_HUGE_VAL);
    }
  else if (x_class == FP_INFINITE)
    {
      /* pow (x, y) signals the invalid operation exception for finite x < 0 and finite non-integer y.  */
      if (signbit(x) && internal_modf (y, &d) != 0.0)
	{
	  return signbit(y) ? 1.0 / -x : -x;
	  /*__FLT_RPT_DOMAIN ("pow", x, y, -__FLT_NAN);
	  return -__FLT_NAN;*/
	}
      odd_y = (internal_modf (__FLT_ABI (ldexp) (y, -1), &d) != 0.0) ? 1 : 0;
      /* pow( -inf, y) = +0 for y<0 and not an odd integer,  */
      if (signbit(x) && signbit(y) && !odd_y)
	return __FLT_CST(0.0);
      /* pow( -inf, y) = -inf for y an odd integer > 0.  */
      if (signbit(x) && !signbit(y) && odd_y)
	return -__FLT_HUGE_VAL;
      /* pow( -inf, y) = +inf for y>0 and not an odd integer.  */
      if (signbit(x) && !signbit(y) && !odd_y)
	return __FLT_HUGE_VAL;
      /* pow (+/-inf, y) is +/-0 with no exception for y an odd integer < 0. */
      if (signbit(y))
      {
        /* pow (+/-inf, y) is +0 with no exception for finite y < 0 and not an odd integer.  */
	return (odd_y && signbit(x) ? -__FLT_CST(0.0) : __FLT_CST(0.0));
      }
      /* pow (+/-inf, y) is +/-inf with no exception for finite y > 0 an odd integer.  */
      /* pow (+/-inf, y) is +inf with no exception for finite y > 0 and not an odd integer.  */
      return (odd_y && signbit(x) ? -__FLT_HUGE_VAL : __FLT_HUGE_VAL);
    }

  if (internal_modf (y, &d) != 0.0)
    {
      if (signbit (x))
	{
	  __FLT_RPT_DOMAIN ("pow", x, y, -__FLT_NAN);
	  return -__FLT_NAN;
	}
      if (y == __FLT_CST(0.5))
	{
	  asm volatile ("fsqrt" : "=t" (rslt) : "0" (x));
	  return rslt;
	}
    }
  else if ((d <= (__FLT_TYPE) INT_MAX && d >= (__FLT_TYPE) INT_MIN))
     return __FLT_ABI (__powi) (x, (int) y);
  /* As exp already checks for minlog and maxlog no further checks are necessary.  */
  rslt = (__FLT_TYPE) exp2l ((long double) y * log2l ((long double) __FLT_ABI(fabs) (x)));

  if (signbit (x) && internal_modf (__FLT_ABI (ldexp) (y, -1), &d) != 0.0)
    rslt = -rslt;
  return rslt;
}
