/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

double rint (double x) {
  double retval = 0.0;
  __asm__ __volatile__ ("frintx %d0, %d1\n\t" : "=w" (retval) : "w" (x));
  return retval;
}
