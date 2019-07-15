/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

float
nextafterf (float x, float y)
{
  union
  {
    float f;
    unsigned int i;
  } u;
  if (isnan (y) || isnan (x))
    return x + y;
  if (x == y )
     /* nextafter (0.0, -O.0) should return -0.0.  */
     return y;
  u.f = x; 
  if (x == 0.0F)
    {
      u.i = 1;
      return y > 0.0F ? u.f : -u.f;
    }
  if (((x > 0.0F) ^ (y > x)) == 0)
    u.i++;
  else
    u.i--;
  return u.f;
}
