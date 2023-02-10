/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <stdarg.h>
#include <stdio.h>

int __cdecl __ms_vsnprintf (char *s,size_t n,const char *format,va_list arg)
{
    int retval;

    /* _vsnprintf() does not work with zero length buffer
     * so count number of character by _vscprintf() call */
    if (n == 0)
        return _vscprintf(format, arg);

    retval = _vsnprintf(s, n, format, arg);

    /* _vsnprintf() does not fill trailing null byte if there is not place for it */
    if (retval < 0 || (size_t)retval == n)
        s[n-1] = '\0';

    /* _vsnprintf() returns negative number if buffer is too small
     * so count number of character by _vscprintf() call */
    if (retval < 0)
        retval = _vscprintf(format, arg);

    return retval;
}
