/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <errno.h>

double
fdim (double x, double y)
{
  int cx = fpclassify (x), cy = fpclassify (y);
  double r;

  if (cx == FP_NAN || cy == FP_NAN
      || (y < 0 && cx == FP_INFINITE && cy == FP_INFINITE))
    return x - y;  /* Take care invalid flag is raised.  */
  if (x <= y)
    return 0.0;
  r = x - y;
  if (fpclassify (r) == FP_INFINITE)
    errno = ERANGE;
  return r;
}
