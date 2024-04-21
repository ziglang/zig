/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

// For ucrt, this function normally is an inline function in stdio.h.
// libmingwex doesn't use the ucrt version of headers, and wassert.c can
// end up requiring a concrete version of it.

#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Winline"
#endif

#undef __MSVCRT_VERSION__
#define _UCRT

#define _snwprintf real__snwprintf

#include <stdarg.h>
#include <stdio.h>

#undef _snwprintf

int __cdecl _snwprintf(wchar_t * restrict _Dest, size_t _Count, const wchar_t * restrict _Format, ...);

int __cdecl _snwprintf(wchar_t * restrict _Dest, size_t _Count, const wchar_t * restrict _Format, ...)
{
  va_list ap;
  int ret;
  va_start(ap, _Format);
  ret = vsnwprintf(_Dest, _Count, _Format, ap);
  va_end(ap);
  return ret;
}

int __cdecl (*__MINGW_IMP_SYMBOL(_snwprintf))(wchar_t *restrict, size_t, const wchar_t *restrict, ...) = _snwprintf;
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
