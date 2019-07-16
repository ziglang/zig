/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#define _NEW_COMPLEX_DOUBLE 1

#include "../complex/complex_internal.h"
#include <errno.h>
#include <math.h>

double hypot (double x, double y)
{
  int x_class = fpclassify (x);
  int y_class = fpclassify (y);

  if (x_class == FP_INFINITE || y_class == FP_INFINITE)
    return __FLT_HUGE_VAL;
  else if (x_class == FP_NAN || y_class == FP_NAN)
    return __FLT_NAN;

  return _hypot (x, y);
}

