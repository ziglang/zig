/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
   nexttowardf.c
   Contributed by Danny Smith <dannysmith@users.sourceforge.net>
   No copyright claimed, absolutely no warranties.

   2005-05-10
*/

#include <math.h>

float
nexttowardf (float x, long double y)
{
  union
  {
    float f;
    unsigned int i;
  } u;

  long double xx = x;

  if (isnan (y) || isnan (x))
    return x + y;
  if (xx == y )
     /* nextafter (0.0, -O.0) should return -0.0.  */
     return y;
  u.f = x; 
  if (x == 0.0F)
    {
      u.i = 1;
      return y > 0.0L ? u.f : -u.f;
    }
  if (((x > 0.0F) ^ (y > xx)) == 0)
    u.i++;
  else
    u.i--;
  return u.f;
}
