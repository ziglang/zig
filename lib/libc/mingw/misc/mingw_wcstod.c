#include <stdio.h>
#include <float.h>
#include <errno.h>
#include <math.h>

extern long double __cdecl
__mingw_wcstold (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr);

double __cdecl
__mingw_wcstod (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr);

double __cdecl
__mingw_wcstod (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr)
{
  long double ret = __mingw_wcstold (_Str, _EndPtr);
  if (isfinite(ret)) {
    /* Check for cases that aren't out of range for long doubles, but that are
     * for doubles. */
    if (ret > DBL_MAX)
      errno = ERANGE;
    else if (ret < -DBL_MAX)
      errno = ERANGE;
    else if (ret > 0 && ret < DBL_MIN)
      errno = ERANGE;
    else if (ret < 0 && ret > -DBL_MIN)
      errno = ERANGE;
  }
  return ret;
}


