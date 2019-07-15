/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>

float
fminf (float _x, float _y)
{
  return ((islessequal(_x, _y) || __isnanf (_y)) ? _x : _y );
}
