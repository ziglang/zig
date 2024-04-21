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

#define fwprintf real_fwprintf

#include <stdarg.h>
#include <stdio.h>

#undef fwprintf

int __cdecl fwprintf(FILE *ptr, const wchar_t *fmt, ...);

int __cdecl fwprintf(FILE *ptr, const wchar_t *fmt, ...)
{
  va_list ap;
  int ret;
  va_start(ap, fmt);
  ret = vfwprintf(ptr, fmt, ap);
  va_end(ap);
  return ret;
}

int __cdecl (*__MINGW_IMP_SYMBOL(fwprintf))(FILE *, const wchar_t *, ...) = fwprintf;
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
