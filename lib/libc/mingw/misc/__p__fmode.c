/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

extern int * __MINGW_IMP_SYMBOL(_fmode);

int *__cdecl __p__fmode(void);
int *__cdecl __p__fmode(void)
{
    return __MINGW_IMP_SYMBOL(_fmode);
}

typeof(__p__fmode) *__MINGW_IMP_SYMBOL(__p__fmode) = __p__fmode;
