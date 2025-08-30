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
    int retval;

    /* _vsnwprintf() does not work with zero length buffer
     * so count number of characters by _vscwprintf() call */
    if (n == 0)
        return _vscwprintf(format, argptr);

    retval = _vsnwprintf(buffer, n, format, argptr);

    /* _vsnwprintf() does not fill trailing null character if there is not place for it */
    if (retval < 0 || (size_t)retval == n)
        buffer[n-1] = '\0';

    /* _vsnwprintf() returns negative number if buffer is too small
     * so count number of characters by _vscwprintf() call */
    if (retval < 0)
        retval = _vscwprintf(format, argptr);

    return retval;
}
