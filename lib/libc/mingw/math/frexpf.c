/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
extern double __cdecl frexp(double _X,int *_Y);

float frexpf (float, int *);
float frexpf (float x, int *expn)
{
  return (float)frexp(x, expn);
}

