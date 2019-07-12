/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
 * complex.h
 *
 * This file is part of the Mingw32 package.
 *
 * Contributors:
 *  Created by Danny Smith <dannysmith@users.sourceforge.net>
 *
 *  THIS SOFTWARE IS NOT COPYRIGHTED
 *
 *  This source code is offered for use in the public domain. You may
 *  use, modify or distribute it freely.
 *
 *  This code is distributed in the hope that it will be useful but
 *  WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 *  DISCLAIMED. This includes but is not limited to warranties of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _COMPLEX_H_
#define _COMPLEX_H_

/* All the headers include this file. */
#include <crtdefs.h>

/* These macros are specified by C99 standard */

#ifndef __cplusplus
#define complex _Complex
#endif

#define _Complex_I  (__extension__  1.0iF)

/* GCC doesn't support _Imaginary type yet, so we don't
   define _Imaginary_I */

#define I _Complex_I

#ifdef __cplusplus
extern "C" {
#endif

#ifndef RC_INVOKED

double __MINGW_ATTRIB_CONST creal (double _Complex);
double __MINGW_ATTRIB_CONST cimag (double _Complex);
double __MINGW_ATTRIB_CONST carg (double _Complex);
double __MINGW_ATTRIB_CONST cabs (double _Complex) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
double _Complex __MINGW_ATTRIB_CONST conj (double _Complex);
double _Complex  cacos (double _Complex);
double _Complex  casin (double _Complex);
double _Complex  catan (double _Complex);
double _Complex  ccos (double _Complex);
double _Complex  csin (double _Complex);
double _Complex  ctan (double _Complex);
double _Complex  cacosh (double _Complex);
double _Complex  casinh (double _Complex);
double _Complex  catanh (double _Complex);
double _Complex  ccosh (double _Complex);
double _Complex  csinh (double _Complex);
double _Complex  ctanh (double _Complex);
double _Complex  cexp (double _Complex);
double _Complex  clog (double _Complex);
#ifdef _GNU_SOURCE
double _Complex  clog10(double _Complex);
#endif  /* _GNU_SOURCE */
double _Complex  cpow (double _Complex, double _Complex);
double _Complex  csqrt (double _Complex);
double _Complex __MINGW_ATTRIB_CONST cproj (double _Complex);

float __MINGW_ATTRIB_CONST crealf (float _Complex);
float __MINGW_ATTRIB_CONST cimagf (float _Complex);
float __MINGW_ATTRIB_CONST cargf (float _Complex);
float __MINGW_ATTRIB_CONST cabsf (float _Complex);
float _Complex __MINGW_ATTRIB_CONST conjf (float _Complex);
float _Complex  cacosf (float _Complex);
float _Complex  casinf (float _Complex);
float _Complex  catanf (float _Complex);
float _Complex  ccosf (float _Complex);
float _Complex  csinf (float _Complex);
float _Complex  ctanf (float _Complex);
float _Complex  cacoshf (float _Complex);
float _Complex  casinhf (float _Complex);
float _Complex  catanhf (float _Complex);
float _Complex  ccoshf (float _Complex);
float _Complex  csinhf (float _Complex);
float _Complex  ctanhf (float _Complex);
float _Complex  cexpf (float _Complex);
float _Complex  clogf (float _Complex);
#ifdef _GNU_SOURCE
float _Complex  clog10f(float _Complex);
#endif  /* _GNU_SOURCE */
float _Complex  cpowf (float _Complex, float _Complex);
float _Complex  csqrtf (float _Complex);
float _Complex __MINGW_ATTRIB_CONST cprojf (float _Complex);

long double __MINGW_ATTRIB_CONST creall (long double _Complex);
long double __MINGW_ATTRIB_CONST cimagl (long double _Complex);
long double __MINGW_ATTRIB_CONST cargl (long double _Complex);
long double __MINGW_ATTRIB_CONST cabsl (long double _Complex);
long double _Complex __MINGW_ATTRIB_CONST conjl (long double _Complex);
long double _Complex  cacosl (long double _Complex);
long double _Complex  casinl (long double _Complex);
long double _Complex  catanl (long double _Complex);
long double _Complex  ccosl (long double _Complex);
long double _Complex  csinl (long double _Complex);
long double _Complex  ctanl (long double _Complex);
long double _Complex  cacoshl (long double _Complex);
long double _Complex  casinhl (long double _Complex);
long double _Complex  catanhl (long double _Complex);
long double _Complex  ccoshl (long double _Complex);
long double _Complex  csinhl (long double _Complex);
long double _Complex  ctanhl (long double _Complex);
long double _Complex  cexpl (long double _Complex);
long double _Complex  clogl (long double _Complex);
#ifdef _GNU_SOURCE
long double _Complex  clog10l(long double _Complex);
#endif  /* _GNU_SOURCE */
long double _Complex  cpowl (long double _Complex, long double _Complex);
long double _Complex  csqrtl (long double _Complex);
long double _Complex __MINGW_ATTRIB_CONST cprojl (long double _Complex);

#ifdef __GNUC__
#if !defined (__CRT__NO_INLINE) && defined (_MATH_H_)
/* double */
__CRT_INLINE double __MINGW_ATTRIB_CONST creal (double _Complex _Z)
{
  return __real__ _Z;
}

__CRT_INLINE double __MINGW_ATTRIB_CONST cimag (double _Complex _Z)
{
  return __imag__ _Z;
}

__CRT_INLINE double _Complex __MINGW_ATTRIB_CONST conj (double _Complex _Z)
{
  return __extension__ ~_Z;
}

__CRT_INLINE  double __MINGW_ATTRIB_CONST carg (double _Complex _Z)
{
  return atan2 (__imag__ _Z, __real__ _Z);
}

__CRT_INLINE double __MINGW_ATTRIB_CONST cabs (double _Complex _Z)
{
  return hypot (__real__ _Z, __imag__ _Z);
}

/* float */
__CRT_INLINE float __MINGW_ATTRIB_CONST crealf (float _Complex _Z)
{
  return __real__ _Z;
}

__CRT_INLINE float __MINGW_ATTRIB_CONST cimagf (float _Complex _Z)
{
  return __imag__ _Z;
}

__CRT_INLINE float _Complex __MINGW_ATTRIB_CONST conjf (float _Complex _Z)
{
  return __extension__ ~_Z;
}

__CRT_INLINE  float __MINGW_ATTRIB_CONST cargf (float _Complex _Z)
{
  return atan2f (__imag__ _Z, __real__ _Z);
}

__CRT_INLINE float __MINGW_ATTRIB_CONST cabsf (float _Complex _Z)
{
  return hypotf (__real__ _Z, __imag__ _Z);
}

/* long double */
__CRT_INLINE long double __MINGW_ATTRIB_CONST creall (long double _Complex _Z)
{
  return __real__ _Z;
}

__CRT_INLINE long double __MINGW_ATTRIB_CONST cimagl (long double _Complex _Z)
{
  return __imag__ _Z;
}

__CRT_INLINE long double _Complex __MINGW_ATTRIB_CONST conjl (long double _Complex _Z)
{
  return __extension__ ~_Z;
}

__CRT_INLINE  long double __MINGW_ATTRIB_CONST cargl (long double _Complex _Z)
{
  return atan2l (__imag__ _Z, __real__ _Z);
}

__CRT_INLINE long double __MINGW_ATTRIB_CONST cabsl (long double _Complex _Z)
{
  return hypotl (__real__ _Z, __imag__ _Z);
}
#endif /* !__CRT__NO_INLINE */
#endif /* __GNUC__ */


#endif /* RC_INVOKED */

#ifdef __cplusplus
}
#endif

#endif /* _COMPLEX_H */
