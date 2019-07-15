/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MINGWEX_FASTMATH_H_
#define _MINGWEX_FASTMATH_H_

/* Fast math inlines
   No range or domain checks. No setting of errno.  No tweaks to
   protect precision near range limits. */

/* For now this is an internal header with just the functions that
   are currently used in building libmingwex.a math components */

/* FIXME: We really should get rid of the code duplication using euther
   C++ templates or tgmath-type macros.  */  

static __inline__ double __fast_sqrt (double x)
{
  double res;
  asm __volatile__ ("fsqrt" : "=t" (res) : "0" (x));
  return res;
}

static __inline__ long double __fast_sqrtl (long double x)
{
  long double res;
  asm __volatile__ ("fsqrt" : "=t" (res) : "0" (x));
  return res;
}

static __inline__ float __fast_sqrtf (float x)
{
  float res;
  asm __volatile__ ("fsqrt" : "=t" (res) : "0" (x));
  return res;
}


static __inline__ double __fast_log (double x)
{
   double res;
   asm __volatile__
     ("fldln2\n\t"
      "fxch\n\t"
      "fyl2x"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}

static __inline__ long double __fast_logl (long double x)
{
  long double res;
   asm __volatile__
     ("fldln2\n\t"
      "fxch\n\t"
      "fyl2x"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}


static __inline__ float __fast_logf (float x)
{
   float res;
   asm __volatile__
     ("fldln2\n\t"
      "fxch\n\t"
      "fyl2x"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}

static __inline__ double __fast_log1p (double x)
{
  double res;
  /* fyl2xp1 accurate only for |x| <= 1.0 - 0.5 * sqrt (2.0) */
  if (fabs (x) >= 1.0 - 0.5 * 1.41421356237309504880)
    res = __fast_log (1.0 + x);
  else
    asm __volatile__
      ("fldln2\n\t"
       "fxch\n\t"
       "fyl2xp1"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}

static __inline__ long double __fast_log1pl (long double x)
{
  long double res;
  /* fyl2xp1 accurate only for |x| <= 1.0 - 0.5 * sqrt (2.0) */
  if (fabsl (x) >= 1.0L - 0.5L * 1.41421356237309504880L)
    res = __fast_logl (1.0L + x);
  else
    asm __volatile__
      ("fldln2\n\t"
       "fxch\n\t"
       "fyl2xp1"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}

static __inline__ float __fast_log1pf (float x)
{
  float res;
  /* fyl2xp1 accurate only for |x| <= 1.0 - 0.5 * sqrt (2.0) */
  if (fabsf (x) >= 1.0 - 0.5 * 1.41421356237309504880)
    res = __fast_logf (1.0 + x);
  else
    asm __volatile__
      ("fldln2\n\t"
       "fxch\n\t"
       "fyl2xp1"
       : "=t" (res) : "0" (x) : "st(1)");
   return res;
}

#endif
