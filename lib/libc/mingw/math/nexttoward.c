/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
   nexttoward.c
   Contributed by Danny Smith <dannysmith@users.sourceforge.net>
   No copyright claimed, absolutely no warranties.

   2005-05-10
*/

#include <math.h>

double
nexttoward (double x, long double y)
{
  union
  {
    double d;
    unsigned long long ll;
  } u;

  long double xx = x;

  if (isnan (y) || isnan (x))
    return x + y;

  if (xx == y)
     /* nextafter (0.0, -O.0) should return -0.0.  */
     return y;
  u.d = x; 
  if (x == 0.0)
    {
      u.ll = 1;
      return y > 0.0L ? u.d : -u.d;
    }

  /* Non-extended encodings are lexicographically ordered,
     with implicit "normal" bit.  */ 
  if (((x > 0.0) ^ (y > xx)) == 0)
    u.ll++;
  else
    u.ll--;
  return u.d;
}
