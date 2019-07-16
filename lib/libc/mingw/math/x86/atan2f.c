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
atan2f (float y, float x)
{
  float res = 0.0F;
  asm volatile ("fpatan" : "=t" (res) : "u" (y), "0" (x) : "st(1)");
  return res;
}
