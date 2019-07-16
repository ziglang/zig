/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <_mingw.h>
#include <stdarg.h>
#include <wchar.h>

int  __cdecl __ms_vsnwprintf(wchar_t *buffer,  size_t n, const wchar_t * format, va_list argptr);

int  __cdecl __ms_vsnwprintf(wchar_t *buffer,  size_t n, const wchar_t * format, va_list argptr)
{
    return _vsnwprintf(buffer, n, format, argptr);
}
