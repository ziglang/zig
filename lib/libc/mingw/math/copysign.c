/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

typedef union U
{
  unsigned int u[2];
  double d;
} U;

double copysign(double x, double y)
{
  U h,j;
  h.d = x;
  j.d = y;
  h.u[1] = (h.u[1] & 0x7fffffff) | (j.u[1] & 0x80000000);
  return h.d;
}
