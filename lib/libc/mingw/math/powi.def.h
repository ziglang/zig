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
 * powi (x, +/-0) is 1 for any x (even a zero, quiet NaN, or infinity)
 * powi (+1, y) is 1 for any y (even a quiet NaN)
 * powi (+/-0, y) is +/-oo and signals the divideByZero exception for y an odd integer < 0
 * powi (+/-0, y) is +oo and signals the divideByZero exception for finite y < 0 and not an odd integer
 * powi (+/-0, y) is +/-0 for finite y > 0 an odd integer
 * powi (+/-0, y) is +0 for finite y > 0 and not an odd integer
 powi (-inf, y) = +0 for y<0 and not an odd integer
 powi (-inf, y) = -inf for y an odd integer > 0
 powi (-inf, y) = +inf for y>0 and not an odd integer
 powi (+/-inf, y) is +/-0 with no exception for y an odd integer < 0
 powi (+/-inf, y) is +0 with no exception for finite y < 0 and not an odd integer
 powi (+/-inf, y) is +/-inf with no exception for finite y > 0 an odd integer
 powi (+/-inf, y) is +inf with no exception for finite y > 0 and not an odd integer
 powi (x, y) signals the invalid operation exception for finite x < 0 and finite non-integer y.
 
 For x /= 0: lim y->oo (1/x)^y results as: for |x| < 1 that sgn(x)*0 and for |x| > 0 that sgn(x)*Infinity

*/
#include "../complex/complex_internal.h"
#include <errno.h>
#include <limits.h>
#include <fenv.h>
#include <math.h>
#include <errno.h>

__FLT_TYPE __cdecl
__FLT_ABI(__powi) (__FLT_TYPE x, int y);

__FLT_TYPE __cdecl
__FLT_ABI(__powi) (__FLT_TYPE x, int y)
{
  int x_class = fpclassify (x);
  int odd_y = y & 1;
  __FLT_TYPE d, rslt;

  if (y == 0 || x == __FLT_CST(1.0))
    return __FLT_CST(1.0);
  else if (x_class == FP_NAN)
    {
      rslt = (signbit(x) ? -__FLT_NAN : __FLT_NAN);
      __FLT_RPT_DOMAIN ("__powi", x, (__FLT_TYPE) y, rslt);
      return rslt;
    }
  else if (x_class == FP_ZERO)
    {
      if (y >= 0)
	{
	  if (!odd_y || !signbit (x))
	    return __FLT_CST (0.0);
	  return -__FLT_CST(0.0);
	}

      if (!odd_y || !signbit (x))
	return __FLT_HUGE_VAL;
      return (signbit(x) ? -__FLT_HUGE_VAL : __FLT_HUGE_VAL);
    }
  else if (x_class == FP_INFINITE)
    {
      /* pow( -inf, y) = +0 for y<0 and not an odd integer,  */
      if (signbit(x) && y < 0 && !odd_y)
	return __FLT_CST(0.0);
      /* pow( -inf, y) = -inf for y an odd integer > 0.  */
      if (signbit(x) && y >= 0 && odd_y)
	return -__FLT_HUGE_VAL;
      /* pow( -inf, y) = +inf for y>0 and not an odd integer.  */
      if (signbit(x) && y >= 0 && !odd_y)
	return __FLT_HUGE_VAL;
      /* pow (+/-inf, y) is +/-0 with no exception for y an odd integer < 0. */
      if (y < 0)
      {
        /* pow (+/-inf, y) is +0 with no exception for finite y < 0 and not an odd integer.  */
	return (odd_y && signbit(x) ? -__FLT_CST(0.0) : __FLT_CST(0.0));
      }
      /* pow (+/-inf, y) is +/-inf with no exception for finite y > 0 an odd integer.  */
      /* pow (+/-inf, y) is +inf with no exception for finite y > 0 and not an odd integer.  */
      return (odd_y && signbit(x) ? -__FLT_HUGE_VAL : __FLT_HUGE_VAL);
    }

  d = __FLT_ABI(fabs) (x);

  if (y < 0)
    {
      d = __FLT_CST(1.0) / d;
      y = -y;
    }

  if (!y)
    rslt = __FLT_CST(1.0);
  else if (y == 1)
    rslt = d;
  else
    {
      unsigned int u = (unsigned int) y;
      rslt = ((u & 1) != 0) ? d : __FLT_CST(1.0);
      u >>= 1;
      do
	{
	  d *= d;
	  if ((u & 1) != 0)
	    rslt *= d;
	  u >>= 1;
	}
      while (u > 0);
    }
  if (signbit (x) && odd_y)
    rslt = -rslt;
  return rslt;
}
