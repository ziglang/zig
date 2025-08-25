/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

float rintf (float x) {
  float retval = 0.0F;
  __asm__ __volatile__ ("frintx %s0, %s1\n\t" : "=w" (retval) : "w" (x));
  return retval;
}
