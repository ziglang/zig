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
__FLT_ABI(casinh) (__FLT_TYPE __complex__ z)
{
  __complex__ __FLT_TYPE ret;
  __complex__ __FLT_TYPE x;
  __FLT_TYPE arz, aiz;
  int r_class = fpclassify (__real__ z);
  int i_class = fpclassify (__imag__ z);

  if (i_class == FP_INFINITE)
  {
    __real__ ret = __FLT_ABI(copysign) (__FLT_HUGE_VAL, __real__ z);
    __imag__ ret = (r_class == FP_NAN
      ? __FLT_NAN
      : (__FLT_ABI(copysign) ((r_class != FP_NAN && r_class != FP_INFINITE) ? __FLT_PI_2 : __FLT_PI_4, __imag__ z)));
    return ret;
  }

  if (r_class == FP_INFINITE)
  {
    __real__ ret = __real__ z;
    __imag__ ret = (i_class != FP_NAN
      ? __FLT_ABI(copysign) (__FLT_CST(0.0), __imag__ z)
      : __FLT_NAN);
    return ret;
  }

  if (r_class == FP_NAN)
  {
    __real__ ret = __real__ z;
    __imag__ ret = (i_class == FP_ZERO
      ? __FLT_ABI(copysign) (__FLT_CST(0.0), __imag__ z)
      : __FLT_NAN);
    return ret;
  }

  if (i_class == FP_NAN)
  {
    __real__ ret = __FLT_NAN;
    __imag__ ret = __FLT_NAN;
    return ret;
  }

  if (r_class == FP_ZERO && i_class == FP_ZERO)
    return z;

  /* casinh(z) = log(z + sqrt(z*z + 1)) */

  /* Use symmetries to perform the calculation in the first quadrant. */
  arz = __FLT_ABI(fabs) (__real__ z);
  aiz = __FLT_ABI(fabs) (__imag__ z);

  if (arz >= __FLT_CST(1.0)/__FLT_EPSILON
      || aiz >= __FLT_CST(1.0)/__FLT_EPSILON)
  {
    /* For large z, z + sqrt(z*z + 1) is approximately 2*z.
    Use that approximation to avoid overflow when squaring. */
    __real__ x = arz;
    __imag__ x = aiz;
    ret = __FLT_ABI(clog) (x);
    __real__ ret += M_LN2;
  }
  else if (aiz < __FLT_CST(1.0) && arz <= __FLT_EPSILON)
  {
    /* Taylor series expansion around arz=0 for z + sqrt(z*z + 1):
    c = arz + sqrt(1-aiz^2) + i*(aiz + arz*aiz / sqrt(1-aiz^2)) + O(arz^2)
    Identity: clog(c) = log(|c|) + i*arg(c)
    For real part of result:
    |c| = 1 + arz / sqrt(1-aiz^2) + O(arz^2)  (Taylor series expansion)
    For imaginary part of result:
    c = (arz + sqrt(1-aiz^2))/sqrt(1-aiz^2) * (sqrt(1-aiz^2) + i*aiz) + O(arz^6)
    */
    __FLT_TYPE s1maiz2 = __FLT_ABI(sqrt) ((__FLT_CST(1.0)+aiz)*(__FLT_CST(1.0)-aiz));
    __real__ ret = __FLT_ABI(log1p) (arz / s1maiz2);
    __imag__ ret = __FLT_ABI(atan2) (aiz, s1maiz2);
  }
  else if (aiz < __FLT_CST(1.0) && arz*arz <= __FLT_EPSILON)
  {
    /* Taylor series expansion around arz=0 for z + sqrt(z*z + 1):
    c = arz + sqrt(1-aiz^2) + arz^2 / (2*(1-aiz^2)^(3/2)) + i*(aiz + arz*aiz / sqrt(1-aiz^2)) + O(arz^4)
    Identity: clog(c) = log(|c|) + i*arg(c)
    For real part of result:
    |c| = 1 + arz / sqrt(1-aiz^2) + arz^2/(2*(1-aiz^2)) + O(arz^3)  (Taylor series expansion)
    For imaginary part of result:
    c = 1/sqrt(1-aiz^2) * ((1-aiz^2) + arz*sqrt(1-aiz^2) + arz^2/(2*(1-aiz^2)) + i*aiz*(sqrt(1-aiz^2)+arz)) + O(arz^3)
    */
    __FLT_TYPE onemaiz2 = (__FLT_CST(1.0)+aiz)*(__FLT_CST(1.0)-aiz);
    __FLT_TYPE s1maiz2 = __FLT_ABI(sqrt) (onemaiz2);
    __FLT_TYPE arz2red = arz * arz / __FLT_CST(2.0) / s1maiz2;
    __real__ ret = __FLT_ABI(log1p) ((arz + arz2red) / s1maiz2);
    __imag__ ret = __FLT_ABI(atan2) (aiz * (s1maiz2 + arz),
                                     onemaiz2 + arz*s1maiz2 + arz2red);
  }
  else
  {
    __real__ x = (arz - aiz) * (arz + aiz) + __FLT_CST(1.0);
    __imag__ x = __FLT_CST(2.0) * arz * aiz;

    x = __FLT_ABI(csqrt) (x);

    __real__ x += arz;
    __imag__ x += aiz;

    ret = __FLT_ABI(clog) (x);
  }

  /* adjust signs for input quadrant */
  __real__ ret = __FLT_ABI(copysign) (__real__ ret, __real__ z);
  __imag__ ret = __FLT_ABI(copysign) (__imag__ ret, __imag__ z);

  return ret;
}
