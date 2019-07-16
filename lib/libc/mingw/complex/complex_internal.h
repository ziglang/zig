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

#include <math.h>
#include <complex.h>

/* Define some PI constants for long double, as they are not defined in math.h  */
#ifndef M_PI_4l
#define M_PI_4l 0.7853981633974483096156608458198757L
#define M_PI_2l 1.5707963267948966192313216916397514L
#define M_PIl   3.1415926535897932384626433832795029L
#endif

/* NAN builtins for gcc, as they are not part of math.h  */
#ifndef NANF
#define NANF __builtin_nanf ("")
#endif
#ifndef NANL
#define NANL __builtin_nanl ("")
#endif

/* Some more helpers.  */
#define M_PI_3_4  (M_PI - M_PI_4)
#define M_PI_3_4l (M_PIl - M_PI_4l)

#if defined(_NEW_COMPLEX_FLOAT)
# define __FLT_TYPE	float
# define __FLT_ABI(N)	N##f
# define __FLT_CST(N)	N##F
# define __FLT_EPSILON  __FLT_EPSILON__
# define __FLT_NAN	NANF
# define __FLT_HUGE_VAL	HUGE_VALF
# define __FLT_PI	M_PI
# define __FLT_PI_2	M_PI_2
# define __FLT_PI_4	M_PI_4
# define __FLT_PI_3_4	M_PI_3_4
# define __FLT_MAXLOG	88.72283905206835F
# define __FLT_MINLOG	-103.278929903431851103F
# define __FLT_LOGE2	0.693147180559945309F
# define __FLT_LOG10E   0.434294481903251828F
# define __FLT_REPORT(NAME) NAME "f"
#elif defined(_NEW_COMPLEX_DOUBLE)
# define __FLT_TYPE	double
# define __FLT_ABI(N)	N
# define __FLT_EPSILON  __DBL_EPSILON__
# define __FLT_CST(N)	N
# define __FLT_NAN	NAN
# define __FLT_HUGE_VAL	HUGE_VAL
# define __FLT_PI	M_PI
# define __FLT_PI_2	M_PI_2
# define __FLT_PI_4	M_PI_4
# define __FLT_PI_3_4	M_PI_3_4
# define __FLT_MAXLOG	7.09782712893383996843E2
# define __FLT_MINLOG	-7.45133219101941108420E2
# define __FLT_LOGE2	6.93147180559945309417E-1
# define __FLT_LOG10E   4.34294481903251827651E-1
# define __FLT_REPORT(NAME)	NAME
#elif defined(_NEW_COMPLEX_LDOUBLE)
# define __FLT_TYPE	long double
# define __FLT_ABI(N)	N##l
# define __FLT_CST(N)	N##L
# define __FLT_EPSILON  __LDBL_EPSILON__
# define __FLT_NAN	NANL
# define __FLT_HUGE_VAL	HUGE_VALL
# define __FLT_PI	M_PIl
# define __FLT_PI_2	M_PI_2l
# define __FLT_PI_4	M_PI_4l
# define __FLT_PI_3_4	M_PI_3_4l
# define __FLT_MAXLOG	1.1356523406294143949492E4L
# define __FLT_MINLOG	-1.1355137111933024058873E4L
# define __FLT_LOGE2	6.9314718055994530941723E-1L
# define __FLT_LOG10E   4.3429448190325182765113E-1L
# define __FLT_REPORT(NAME) NAME "l"
#else
# error "Unknown complex number type"
#endif

#define __FLT_RPT_DOMAIN(NAME, ARG1, ARG2, RSLT) \
	errno = EDOM, \
	__mingw_raise_matherr (_DOMAIN, __FLT_REPORT(NAME), (double) (ARG1), \
			       (double) (ARG2), (double) (RSLT))
#define __FLT_RPT_ERANGE(NAME, ARG1, ARG2, RSLT, OVL) \
	errno = ERANGE, \
        __mingw_raise_matherr (((OVL) ? _OVERFLOW : _UNDERFLOW), \
			       __FLT_REPORT(NAME), (double) (ARG1), \
                               (double) (ARG2), (double) (RSLT))

