/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

void sincos (double __x, double *p_sin, double *p_cos)
{
  *p_sin = sin(__x);
  *p_cos = cos(__x);
}

void sincosf (float __x, float *p_sin, float *p_cos)
{
  *p_sin = sinf(__x);
  *p_cos = cosf(__x);
}

void sincosl (long double __x, long double *p_sin, long double *p_cos)
{
#if defined(__arm__) || defined(_ARM_)
  *p_sin = sin(__x);
  *p_cos = cos(__x);
#else
#error Not supported on your platform yet
#endif
}
