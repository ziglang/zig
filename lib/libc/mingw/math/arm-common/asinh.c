/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

double asinh(double x)
{
  if (isinf(x*x + 1)) {
    if (x > 0)
      return log(2) + log(x);
    else
      return -log(2) - log(-x);
  }
  return log(x + sqrt(x*x + 1));
}
