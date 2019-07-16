/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <locale.h>

int __cdecl _configthreadlocale(int flag)
{
    /* _ENABLE_PER_THREAD_LOCALE can't work on msvcrt.dll. */
    return flag == _ENABLE_PER_THREAD_LOCALE ? -1 : _DISABLE_PER_THREAD_LOCALE;
}

void *__MINGW_IMP_SYMBOL(_configthreadlocale) = _configthreadlocale;

