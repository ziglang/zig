/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
 * Written by J.T. Conklin <jtc@netbsd.org>.
 * Public domain.
 *
 */

#include <math.h>

float
atanf (float x)
{
  float res = 0.0F;

  asm volatile (
       "fld1\n\t"
       "fpatan" : "=t" (res) : "0" (x));
  return res;
}
