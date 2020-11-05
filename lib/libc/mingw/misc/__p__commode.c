/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

extern int * __MINGW_IMP_SYMBOL(_commode);

int *__cdecl __p__commode(void);
int *__cdecl __p__commode(void)
{
    return __MINGW_IMP_SYMBOL(_commode);
}

typeof(__p__commode) *__MINGW_IMP_SYMBOL(__p__commode) = __p__commode;
