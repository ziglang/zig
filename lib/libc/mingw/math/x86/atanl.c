/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
long double atanl (long double x);

long double
atanl (long double x)
{
  long double res = 0.0L;

  asm volatile (
       "fld1\n\t"
       "fpatan"
       : "=t" (res) : "0" (x));
  return res;
}
