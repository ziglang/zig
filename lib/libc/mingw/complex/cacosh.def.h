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

__FLT_TYPE __complex__ __cdecl
__FLT_ABI(cacosh) (__FLT_TYPE __complex__ z)
{
  __complex__ __FLT_TYPE ret;
  __complex__ __FLT_TYPE x;
  int r_class = fpclassify (__real__ z);
  int i_class = fpclassify (__imag__ z);

  if (i_class == FP_INFINITE)
  {
    __real__ ret = __FLT_HUGE_VAL;
    __imag__ ret = (r_class == FP_NAN ? __FLT_NAN : __FLT_ABI(copysign) (
      (r_class == FP_INFINITE ? (__real__ z < __FLT_CST(0.0) ? __FLT_PI_3_4 : __FLT_PI_4) : __FLT_PI_2), __imag__ z));
    return ret;
  }

  if (r_class == FP_INFINITE)
  {
    __real__ ret = __FLT_HUGE_VAL;
    __imag__ ret = ((i_class != FP_NAN && i_class != FP_INFINITE)
      ? __FLT_ABI(copysign) (signbit (__real__ z) ? __FLT_PI : __FLT_CST(0.0), __imag__ z) : __FLT_NAN);
    return ret;
  }

  if (r_class == FP_NAN || i_class == FP_NAN)
  {
    __real__ ret = __FLT_NAN;
    __imag__ ret = __FLT_NAN;
    return ret;
  }

  if (r_class == FP_ZERO && i_class == FP_ZERO)
  {
    __real__ ret = __FLT_CST(0.0);
    __imag__ ret = __FLT_ABI(copysign) (__FLT_PI_2, __imag__ z);
    return ret;
  }

  /* cacosh(z) = log(z + sqrt(z*z - 1)) */

  if (__FLT_ABI(fabs) (__real__ z) >= __FLT_CST(1.0)/__FLT_EPSILON
      || __FLT_ABI(fabs) (__imag__ z) >= __FLT_CST(1.0)/__FLT_EPSILON)
  {
    /* For large z, z + sqrt(z*z - 1) is approximately 2*z.
    Use that approximation to avoid overflow when squaring.
    Additionally, use symmetries to perform the calculation in the positive
    half plane. */
    __real__ x = __real__ z;
    __imag__ x = __FLT_ABI(fabs) (__imag__ z);
    x = __FLT_ABI(clog) (x);
    __real__ x += M_LN2;

    /* adjust signs for input */
    __real__ ret = __real__ x;
    __imag__ ret = __FLT_ABI(copysign) (__imag__ x, __imag__ z);

    return ret;
  }

  __real__ x = (__real__ z - __imag__ z) * (__real__ z + __imag__ z) - __FLT_CST(1.0);
  __imag__ x = __FLT_CST(2.0) * __real__ z * __imag__ z;

  x = __FLT_ABI(csqrt) (x);

  if (signbit (__real__ z))
    x = -x;

  __real__ x += __real__ z;
  __imag__ x += __imag__ z;

  ret = __FLT_ABI(clog) (x);

  if (signbit (__real__ ret))
    ret = -ret;

  return ret;
}
