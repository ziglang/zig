/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
extern double __cdecl ldexp(double _X,int _Y);

float ldexpf (float x, int expn);
float ldexpf (float x, int expn)
{
  return (float) ldexp (x, expn);
}

