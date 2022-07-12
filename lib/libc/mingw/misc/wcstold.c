/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdlib.h>

long double wcstold (const wchar_t * __restrict__ wcs, wchar_t ** __restrict__ wcse)
{
  return __mingw_wcstold(wcs, wcse);
}
