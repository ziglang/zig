/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <errno.h>

double remainder(double x, double y)
{
  int iret;
  return remquo(x, y, &iret);
}
