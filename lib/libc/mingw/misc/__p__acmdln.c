/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

extern char ** __MINGW_IMP_SYMBOL(_acmdln);

char **__cdecl __p__acmdln(void);
char **__cdecl __p__acmdln(void)
{
    return __MINGW_IMP_SYMBOL(_acmdln);
}

typedef char **__cdecl (*_f__p__acmdln)(void);
_f__p__acmdln __MINGW_IMP_SYMBOL(__p__acmdln) = __p__acmdln;
