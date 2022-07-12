/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdlib.h>
#include <float.h>
#include <errno.h>
#include <math.h>

float strtof( const char *nptr, char **endptr)
{
  double ret = strtod(nptr, endptr);
  if (isfinite(ret)) {
    /* Check for cases that aren't out of range for doubles, but that are
     * for floats. */
    if (ret > FLT_MAX)
      errno = ERANGE;
    else if (ret < -FLT_MAX)
      errno = ERANGE;
    else if (ret > 0 && ret < FLT_MIN)
      errno = ERANGE;
    else if (ret < 0 && ret > -FLT_MIN)
      errno = ERANGE;
  }
  return ret;
}
